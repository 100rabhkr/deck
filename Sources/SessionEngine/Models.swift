import Foundation

/// Which coding agent a session belongs to. Agent-agnostic by design; new kinds
/// are added here without touching discovery logic.
public enum AgentKind: String, Codable, Sendable {
    case claude
    case codex
    case unknown
}

/// The three-state model that makes the memory win possible.
/// - live: an agent process is running and holding RAM.
/// - warm: a terminal/pane is open but the agent exited; resumes instantly, ~0 RAM.
/// - cold: no pane, only session history on disk; resume = open a shell + resume.
public enum SessionStatus: String, Codable, Sendable {
    case live
    case warm
    case cold
}

/// A running agent process mapped to the folder it is working in.
public struct LiveAgent: Codable, Sendable, Identifiable {
    public var id: Int { pid }
    public let pid: Int
    public let kind: AgentKind
    public let folder: String
    public let uptimeSeconds: Int
    public let uptimeText: String
    public let rssMB: Int

    public init(pid: Int, kind: AgentKind, folder: String,
                uptimeSeconds: Int, uptimeText: String, rssMB: Int) {
        self.pid = pid
        self.kind = kind
        self.folder = folder
        self.uptimeSeconds = uptimeSeconds
        self.uptimeText = uptimeText
        self.rssMB = rssMB
    }

    /// A small resident size usually means the agent is parked at a prompt,
    /// waiting for input. Useful hint for "safe to sleep and reclaim nothing lost".
    public var isLikelyIdle: Bool { rssMB < 40 }

    public var folderName: String { (folder as NSString).lastPathComponent }
}

/// A listening dev server (node/vite/next/etc.) with its port and how long it
/// has been alive. Orphaned ones are a classic slow RAM leak.
public struct DevServer: Codable, Sendable, Identifiable {
    public var id: Int { pid }
    public let pid: Int
    public let command: String
    public let port: Int
    public let uptimeSeconds: Int
    public let uptimeText: String
    public let folder: String

    public init(pid: Int, command: String, port: Int,
                uptimeSeconds: Int, uptimeText: String, folder: String) {
        self.pid = pid
        self.command = command
        self.port = port
        self.uptimeSeconds = uptimeSeconds
        self.uptimeText = uptimeText
        self.folder = folder
    }

    public var folderName: String { (folder as NSString).lastPathComponent }
}
