import Foundation
import SwiftUI
import Termini
import SessionEngine

/// Owns the open terminals. Opening a session runs the right agent-resume
/// command in its folder (so you land back in the conversation, not a bare
/// prompt), keeps each terminal alive as you switch tabs, and can sleep one to
/// reclaim its RAM.
@MainActor
final class TerminalManager: ObservableObject {
    /// Open terminals, in tab order.
    @Published private(set) var openOrder: [String] = []
    /// Folders we could not read (usually macOS privacy/TCC), opened in home instead.
    @Published private(set) var noAccess: Set<String> = []
    private var workspaces: [String: TerminiLocalPTYWorkspace] = [:]

    func open(folder: String, kinds: [AgentKind]) {
        guard workspaces[folder] == nil else { return }
        workspaces[folder] = makeWorkspace(folder: folder, explicitCommand: nil, kinds: kinds)
        openOrder.append(folder)
    }

    /// Open a folder resuming a specific session (from the picker).
    func open(folder: String, command: String) {
        guard workspaces[folder] == nil else { return }
        workspaces[folder] = makeWorkspace(folder: folder, explicitCommand: command, kinds: [])
        openOrder.append(folder)
    }

    func controller(for folder: String) -> TerminiTerminalController? {
        workspaces[folder]?.controller
    }

    func isOpen(_ folder: String) -> Bool { workspaces[folder] != nil }

    /// Stop and forget a terminal (reclaim RAM). The session stays resumable.
    func close(folder: String) {
        workspaces[folder]?.stop()
        workspaces[folder] = nil
        openOrder.removeAll { $0 == folder }
    }

    func folderName(_ folder: String) -> String { (folder as NSString).lastPathComponent }

    // MARK: - internals

    private func makeWorkspace(folder: String, explicitCommand: String?, kinds: [AgentKind]) -> TerminiLocalPTYWorkspace {
        let fm = FileManager.default
        // Must be readable, not just present. A TCC-blocked folder "exists" but
        // returns EPERM, which would leave the shell in an unreadable cwd and
        // make tools like brew fail on startup. Fall back to home in that case.
        let readable = fm.isReadableFile(atPath: folder)
        if readable { noAccess.remove(folder) } else { noAccess.insert(folder) }
        let dir = readable ? URL(fileURLWithPath: folder) : fm.homeDirectoryForCurrentUser
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        let arguments: [String]
        if readable, let cmd = explicitCommand ?? resumeCommand(for: kinds) {
            // Interactive login shell so PATH is fully set, run the resume
            // command, then drop to a normal shell in the same folder when the
            // agent exits (so the tab stays useful instead of dying).
            arguments = ["-l", "-i", "-c", "\(cmd); exec \(shell) -l"]
        } else {
            // Not readable, or no agent to resume: just a shell.
            arguments = ["-l"]
        }

        let spec = TerminiProcessSpec(
            executableURL: URL(fileURLWithPath: shell),
            arguments: arguments,
            environment: ProcessInfo.processInfo.environment,
            workingDirectoryURL: dir)

        let ws = TerminiLocalPTYWorkspace(processSpec: spec)
        ws.start()
        return ws
    }

    /// Which command drops you back into the session. Claude preferred, then
    /// Codex, else a plain shell (nil).
    private func resumeCommand(for kinds: [AgentKind]) -> String? {
        if kinds.contains(.claude) { return "claude --continue" }
        if kinds.contains(.codex) { return "codex resume --last" }
        return nil
    }
}
