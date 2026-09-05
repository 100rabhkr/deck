import Foundation
import Darwin

/// Reads live session and dev-server state from the OS.
public enum Discovery {
    static let ps = "/bin/ps"
    static let lsof = "/usr/sbin/lsof"

    // MARK: - Time helpers

    /// Parse a `ps` etime string into seconds. Forms: `SS`, `MM:SS`, `HH:MM:SS`,
    /// `DD-HH:MM:SS`.
    static func parseEtime(_ raw: String) -> Int {
        var days = 0
        var rest = raw
        if let dash = raw.firstIndex(of: "-") {
            days = Int(raw[raw.startIndex..<dash]) ?? 0
            rest = String(raw[raw.index(after: dash)...])
        }
        let parts = rest.split(separator: ":").map { Int($0) ?? 0 }
        var h = 0, m = 0, s = 0
        switch parts.count {
        case 3: h = parts[0]; m = parts[1]; s = parts[2]
        case 2: m = parts[0]; s = parts[1]
        case 1: s = parts[0]
        default: break
        }
        return ((days * 24 + h) * 60 + m) * 60 + s
    }

    static func humanUptime(_ seconds: Int) -> String {
        let d = seconds / 86400
        let h = (seconds % 86400) / 3600
        let m = (seconds % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    // MARK: - Batched process lookups

    /// Working directories for many pids in a single `lsof` call. Spawning lsof
    /// once per pid is the dominant cost, so batch it: one call, field-parsed.
    static func cwds(ofPids pids: [Int]) -> [Int: String] {
        guard !pids.isEmpty else { return [:] }
        let list = pids.map(String.init).joined(separator: ",")
        let out = Shell.run(lsof, ["-a", "-d", "cwd", "-p", list, "-Fpn"])
        var map: [Int: String] = [:]
        var current: Int?
        for line in out.split(separator: "\n") {
            if line.hasPrefix("p") { current = Int(line.dropFirst()) }
            else if line.hasPrefix("n"), let pid = current { map[pid] = String(line.dropFirst()) }
        }
        return map
    }

    /// Elapsed seconds for many pids in a single `ps` call.
    static func etimes(ofPids pids: [Int]) -> [Int: Int] {
        guard !pids.isEmpty else { return [:] }
        let out = Shell.run(ps, ["-o", "pid=,etime=", "-p", pids.map(String.init).joined(separator: ",")])
        var map: [Int: Int] = [:]
        for line in out.split(separator: "\n") {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard cols.count >= 2, let pid = Int(cols[0]) else { continue }
            map[pid] = parseEtime(cols[1])
        }
        return map
    }

    // MARK: - Live agents

    /// Every running claude/codex process, mapped to its folder, uptime and RAM.
    public static func liveAgents() -> [LiveAgent] {
        struct Cand { let pid: Int; let kind: AgentKind; let etime: String; let rssKB: Int }
        let out = Shell.run(ps, ["-axo", "pid=,etime=,rss=,comm="])
        var cands: [Cand] = []
        for line in out.split(separator: "\n") {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard cols.count >= 4, let pid = Int(cols[0]) else { continue }
            // comm can be a path (and paths can contain spaces): rejoin the tail.
            let base = (cols[3...].joined(separator: " ") as NSString).lastPathComponent
            let kind: AgentKind
            switch base {
            case "claude": kind = .claude
            case "codex":  kind = .codex
            default: continue
            }
            cands.append(Cand(pid: pid, kind: kind, etime: cols[1], rssKB: Int(cols[2]) ?? 0))
        }
        let folders = cwds(ofPids: cands.map { $0.pid })
        var agents: [LiveAgent] = []
        for c in cands {
            guard let folder = folders[c.pid] else { continue }
            let secs = parseEtime(c.etime)
            agents.append(LiveAgent(
                pid: c.pid, kind: c.kind, folder: folder,
                uptimeSeconds: secs, uptimeText: humanUptime(secs),
                rssMB: c.rssKB / 1024))
        }
        return agents.sorted { $0.rssMB > $1.rssMB }
    }

    // MARK: - Open shells (proxy for "a terminal is open here")

    private static let shellNames: Set<String> = ["zsh", "bash", "fish", "sh", "nu"]

    /// Folders that currently have an interactive shell sitting in them. Used to
    /// tell a "warm" session (terminal open, agent exited) from a "cold" one.
    public static func shellFolders() -> Set<String> {
        let out = Shell.run(ps, ["-axo", "pid=,comm="])
        var pids: [Int] = []
        for line in out.split(separator: "\n") {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard cols.count >= 2, let pid = Int(cols[0]) else { continue }
            let base = (cols[1...].joined(separator: " ") as NSString).lastPathComponent
            if shellNames.contains(base) { pids.append(pid) }
        }
        return Set(cwds(ofPids: pids).values)
    }

    // MARK: - Dev servers

    private static let serverCommands = ["node", "bun", "deno", "vite", "next"]

    /// Listening node-family dev servers with port, uptime and folder.
    public static func devServers() -> [DevServer] {
        struct Cand { let pid: Int; let command: String; let port: Int }
        let out = Shell.run(lsof, ["-iTCP", "-sTCP:LISTEN", "-nP"])
        var cands: [Cand] = []
        var seen = Set<Int>()
        for line in out.split(separator: "\n") {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard cols.count >= 9, let pid = Int(cols[1]) else { continue }
            let command = cols[0]
            guard serverCommands.contains(where: { command.hasPrefix($0) }) else { continue }
            if seen.contains(pid) { continue }   // one row per pid (its first listen port)

            let addr = cols[8]                     // e.g. *:5173, 127.0.0.1:3000, [::1]:3000
            guard let portStr = addr.split(separator: ":").last, let port = Int(portStr) else { continue }
            seen.insert(pid)
            cands.append(Cand(pid: pid, command: command, port: port))
        }
        let folders = cwds(ofPids: cands.map { $0.pid })
        let ages = etimes(ofPids: cands.map { $0.pid })
        return cands.map { c in
            let secs = ages[c.pid] ?? 0
            return DevServer(pid: c.pid, command: c.command, port: c.port,
                             uptimeSeconds: secs, uptimeText: humanUptime(secs),
                             folder: folders[c.pid] ?? "?")
        }.sorted { $0.port < $1.port }
    }

    // MARK: - Actions

    /// "Sleep" a live agent: send SIGTERM so it exits cleanly, freeing its RAM.
    /// The session history stays on disk, so it can be resumed later. Refuses any
    /// pid that is not currently a known claude/codex agent.
    @discardableResult
    public static func sleepAgent(pid: Int) -> Bool {
        guard liveAgents().contains(where: { $0.pid == pid }) else { return false }
        return kill(pid_t(pid), SIGTERM) == 0
    }
}
