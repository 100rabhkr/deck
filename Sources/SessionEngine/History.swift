import Foundation

/// Builds the warm/cold session history from on-disk session stores, and unifies
/// it with the live process view into the rows a home screen renders.
///
/// Session stores read (each is optional and independently absent-safe):
///   ~/.claude/projects/<slug>/*.jsonl   (Claude Code)
///   ~/.codex/sessions/YYYY/MM/DD/*.jsonl (Codex)
public enum History {
    struct RawSession {
        let folder: String
        let kind: AgentKind
        let last: Date
        let count: Int
    }

    // MARK: - Reading session files

    /// Pull the recorded working directory out of a session file's header. The
    /// on-disk slug is a lossy encoding of the path (spaces and dots all become
    /// dashes), so the file's own `cwd` field is the reliable source of truth.
    static func parseCwd(fromFile path: String) -> String? {
        guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? fh.close() }
        let data = fh.readData(ofLength: 32_768)
        guard let s = String(data: data, encoding: .utf8),
              let r = s.range(of: "\"cwd\":\"") else { return nil }
        let after = s[r.upperBound...]
        guard let end = after.firstIndex(of: "\"") else { return nil }
        return String(after[..<end]).replacingOccurrences(of: "\\/", with: "/")
    }

    // MARK: - Claude

    static func claudeSessions() -> [RawSession] {
        let fm = FileManager.default
        let root = NSString(string: "~/.claude/projects").expandingTildeInPath
        guard let dirs = try? fm.contentsOfDirectory(atPath: root) else { return [] }
        var out: [RawSession] = []
        for d in dirs {
            let dir = root + "/" + d
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue,
                  let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }

            var count = 0
            var newest: (path: String, date: Date)?
            for it in items where it.hasSuffix(".jsonl") {
                let full = dir + "/" + it
                var fdir: ObjCBool = false
                fm.fileExists(atPath: full, isDirectory: &fdir)
                if fdir.boolValue { continue }
                count += 1
                if let m = (try? fm.attributesOfItem(atPath: full))?[.modificationDate] as? Date {
                    if newest == nil || m > newest!.date { newest = (full, m) }
                }
            }
            guard count > 0, let n = newest else { continue }
            let folder = parseCwd(fromFile: n.path) ?? decodeSlug(d)
            out.append(RawSession(folder: folder, kind: .claude, last: n.date, count: count))
        }
        return out
    }

    /// Last-resort path recovery when a session file has no readable cwd.
    static func decodeSlug(_ slug: String) -> String {
        var s = slug
        if s.hasPrefix("-") { s.removeFirst() }
        return "/" + s.replacingOccurrences(of: "-", with: "/")
    }

    /// First user-message text from a transcript, truncated, for the picker.
    static func firstUserText(fromFile path: String) -> String {
        guard let fh = FileHandle(forReadingAtPath: path) else { return "" }
        defer { try? fh.close() }
        let data = fh.readData(ofLength: 65_536)
        guard let s = String(data: data, encoding: .utf8),
              let r = s.range(of: "\"text\":\"") else { return "" }
        var out = ""
        var esc = false
        var i = r.upperBound
        while i < s.endIndex, out.count < 100 {
            let c = s[i]
            if esc { out.append(c); esc = false }
            else if c == "\\" { esc = true }
            else if c == "\"" { break }
            else { out.append(c) }
            i = s.index(after: i)
        }
        return out.replacingOccurrences(of: "\\n", with: " ").trimmingCharacters(in: .whitespaces)
    }

    /// Every saved Claude conversation whose recorded cwd is `folder`, newest
    /// first. Used by the resume picker when a folder has more than one.
    public static func claudeSessions(inFolder folder: String) -> [SessionRecord] {
        let fm = FileManager.default
        let root = NSString(string: "~/.claude/projects").expandingTildeInPath
        guard let dirs = try? fm.contentsOfDirectory(atPath: root) else { return [] }

        var records: [SessionRecord] = []
        for d in dirs {
            let dir = root + "/" + d
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue,
                  let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            let jsonls = items.filter { $0.hasSuffix(".jsonl") }
            guard !jsonls.isEmpty else { continue }

            // Does this project dir belong to `folder`? Test its newest transcript's cwd.
            var newest: (path: String, date: Date)?
            for it in jsonls {
                let full = dir + "/" + it
                var fdir: ObjCBool = false
                fm.fileExists(atPath: full, isDirectory: &fdir); if fdir.boolValue { continue }
                if let m = (try? fm.attributesOfItem(atPath: full))?[.modificationDate] as? Date {
                    if newest == nil || m > newest!.date { newest = (full, m) }
                }
            }
            guard let n = newest, parseCwd(fromFile: n.path) == folder else { continue }

            for it in jsonls {
                let full = dir + "/" + it
                var fdir: ObjCBool = false
                fm.fileExists(atPath: full, isDirectory: &fdir); if fdir.boolValue { continue }
                let stem = (it as NSString).deletingPathExtension
                let m = (try? fm.attributesOfItem(atPath: full))?[.modificationDate] as? Date ?? .distantPast
                records.append(SessionRecord(sessionId: stem, folder: folder,
                                             lastActivity: m, preview: firstUserText(fromFile: full)))
            }
        }
        return records.sorted { $0.lastActivity > $1.lastActivity }
    }

    // MARK: - Codex

    static func codexSessions(limit: Int = 200) -> [RawSession] {
        let fm = FileManager.default
        let root = NSString(string: "~/.codex/sessions").expandingTildeInPath
        guard let en = fm.enumerator(atPath: root) else { return [] }

        // Collect .jsonl paths with mtime, take the newest `limit` to bound cost.
        var files: [(path: String, date: Date)] = []
        for case let p as String in en where p.hasSuffix(".jsonl") {
            let full = root + "/" + p
            let m = (try? fm.attributesOfItem(atPath: full))?[.modificationDate] as? Date ?? .distantPast
            files.append((full, m))
        }
        files.sort { $0.date > $1.date }
        let recent = files.prefix(limit)

        var byFolder: [String: (last: Date, count: Int)] = [:]
        for f in recent {
            guard let folder = parseCwd(fromFile: f.path) else { continue }
            if let cur = byFolder[folder] {
                byFolder[folder] = (max(cur.last, f.date), cur.count + 1)
            } else {
                byFolder[folder] = (f.date, 1)
            }
        }
        return byFolder.map { RawSession(folder: $0.key, kind: .codex, last: $0.value.last, count: $0.value.count) }
    }

    // MARK: - Unified view

    /// Every project folder with saved sessions, tagged live/warm/cold, newest
    /// first. `includeContext` attaches a one-line summary per folder via the
    /// provider chain (git by default, brain if present).
    public static func entries(includeContext: Bool = true) -> [HistoryEntry] {
        let live = Discovery.liveAgents()
        let liveFolders = Set(live.map { $0.folder })
        let liveKinds = Dictionary(grouping: live, by: { $0.folder })
        let shellFolders = Discovery.shellFolders()

        var merged: [String: (kinds: Set<AgentKind>, last: Date, count: Int)] = [:]
        func absorb(_ r: RawSession) {
            if var m = merged[r.folder] {
                m.kinds.insert(r.kind); m.last = max(m.last, r.last); m.count += r.count
                merged[r.folder] = m
            } else {
                merged[r.folder] = ([r.kind], r.last, r.count)
            }
        }
        claudeSessions().forEach(absorb)
        codexSessions().forEach(absorb)

        // Make sure every currently-live folder is represented, even if its live
        // cwd differs from the folder its transcript was first launched in.
        let now = Date()
        for folder in liveFolders where merged[folder] == nil {
            let kinds = Set((liveKinds[folder] ?? []).map { $0.kind })
            merged[folder] = (kinds.isEmpty ? [.unknown] : kinds, now, 0)
        }

        let resolver = includeContext ? ContextResolver() : nil
        var entries: [HistoryEntry] = []
        for (folder, m) in merged {
            let status: SessionStatus = liveFolders.contains(folder)
                ? .live
                : (shellFolders.contains(folder) ? .warm : .cold)
            let ctx = resolver?.context(forFolder: folder)
            entries.append(HistoryEntry(
                folder: folder,
                kinds: m.kinds.map { $0.rawValue }.sorted().compactMap(AgentKind.init(rawValue:)),
                sessionCount: m.count,
                lastActivity: m.last,
                status: status,
                summary: ctx?.summary,
                summarySource: ctx?.source))
        }
        return entries.sorted { $0.lastActivity > $1.lastActivity }
    }
}
