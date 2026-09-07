import Foundation
import SwiftUI
import Termini
import SessionEngine

/// Owns the open terminals. Opening a session gives you a plain shell in its
/// folder, nothing heavy is spawned. Resuming the agent is a one-touch action
/// that injects the resume command into that shell. Terminals stay alive as you
/// switch; `close` stops one to reclaim RAM.
@MainActor
final class TerminalManager: ObservableObject {
    /// Open terminals, in tab/grid order.
    @Published private(set) var openOrder: [String] = []
    /// Folders we could not read (usually macOS privacy/TCC), opened in home instead.
    @Published private(set) var noAccess: Set<String> = []
    private var workspaces: [String: TerminiLocalPTYWorkspace] = [:]

    func open(folder: String) {
        guard workspaces[folder] == nil else { return }
        workspaces[folder] = makeShell(folder: folder)
        openOrder.append(folder)
    }

    func controller(for folder: String) -> TerminiTerminalController? {
        workspaces[folder]?.controller
    }

    func isOpen(_ folder: String) -> Bool { workspaces[folder] != nil }

    /// Type a command into the folder's shell and run it (one-touch resume).
    func run(_ command: String, in folder: String) {
        workspaces[folder]?.send(Data((command + "\r").utf8))
    }

    /// Stop and forget a terminal (reclaim RAM). The session stays resumable.
    func close(folder: String) {
        workspaces[folder]?.stop()
        workspaces[folder] = nil
        openOrder.removeAll { $0 == folder }
    }

    func folderName(_ folder: String) -> String { (folder as NSString).lastPathComponent }

    /// The agent to offer a Resume button for ("claude" / "codex" / nil).
    func agentLabel(for kinds: [AgentKind]) -> String? {
        if kinds.contains(.claude) { return "claude" }
        if kinds.contains(.codex) { return "codex" }
        return nil
    }

    // MARK: - internals

    private func makeShell(folder: String) -> TerminiLocalPTYWorkspace {
        let fm = FileManager.default
        // Must be readable, not just present. A TCC-blocked folder "exists" but
        // returns EPERM, which would leave the shell in an unreadable cwd. Fall
        // back to home in that case.
        let readable = fm.isReadableFile(atPath: folder)
        if readable { noAccess.remove(folder) } else { noAccess.insert(folder) }
        let dir = readable ? URL(fileURLWithPath: folder) : fm.homeDirectoryForCurrentUser
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        let spec = TerminiProcessSpec(
            executableURL: URL(fileURLWithPath: shell),
            arguments: ["-l"],
            environment: ProcessInfo.processInfo.environment,
            workingDirectoryURL: dir)

        let ws = TerminiLocalPTYWorkspace(processSpec: spec)
        ws.start()
        return ws
    }
}
