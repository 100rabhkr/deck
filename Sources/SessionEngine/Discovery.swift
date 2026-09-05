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

    // MARK: - Process working directory

    /// The current working directory of a pid, via `lsof`.
    static func cwd(ofPid pid: Int) -> String? {
        let out = Shell.run(lsof, ["-a", "-d", "cwd", "-p", "\(pid)", "-Fn"])
        for line in out.split(separator: "\n") where line.hasPrefix("n") {
            return String(line.dropFirst())
        }
        return nil
    }

    // MARK: - Live agents

    /// Every running claude/codex process, mapped to its folder, uptime and RAM.
    public static func liveAgents() -> [LiveAgent] {
        let out = Shell.run(ps, ["-axo", "pid=,etime=,rss=,comm="])
        var agents: [LiveAgent] = []
        for line in out.split(separator: "\n") {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard cols.count >= 4, let pid = Int(cols[0]) else { continue }
            let etime = cols[1]
            let rssKB = Int(cols[2]) ?? 0
            // comm can be a path (and paths can contain spaces): rejoin the tail.
            let comm = cols[3...].joined(separator: " ")
            let base = (comm as NSString).lastPathComponent

            let kind: AgentKind
            switch base {
            case "claude": kind = .claude
            case "codex":  kind = .codex
            default: continue
            }
            guard let folder = cwd(ofPid: pid) else { continue }

            let secs = parseEtime(etime)
            agents.append(LiveAgent(
                pid: pid, kind: kind, folder: folder,
                uptimeSeconds: secs, uptimeText: humanUptime(secs),
                rssMB: rssKB / 1024))
        }
        return agents.sorted { $0.rssMB > $1.rssMB }
    }

    // MARK: - Dev servers

    private static let serverCommands = ["node", "bun", "deno", "vite", "next"]

    /// Listening node-family dev servers with port, uptime and folder.
    public static func devServers() -> [DevServer] {
        let out = Shell.run(lsof, ["-iTCP", "-sTCP:LISTEN", "-nP"])
        var servers: [DevServer] = []
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

            let etime = Shell.run(ps, ["-o", "etime=", "-p", "\(pid)"])
            let secs = parseEtime(etime)
            let folder = cwd(ofPid: pid) ?? "?"
            servers.append(DevServer(
                pid: pid, command: command, port: port,
                uptimeSeconds: secs, uptimeText: humanUptime(secs), folder: folder))
        }
        return servers.sorted { $0.port < $1.port }
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
