import Foundation
import SwiftUI
import Termini
import SessionEngine

/// Owns the open terminals. Opening a session gives a plain shell in its folder;
/// resuming the agent is a one-touch action that injects the command. Watches
/// each session's output for the bell and raises an attention signal for any
/// session that is not the one you are looking at.
@MainActor
final class TerminalManager: ObservableObject {
    static let shared = TerminalManager()

    @Published private(set) var openOrder: [String] = []
    @Published private(set) var noAccess: Set<String> = []
    /// Folders whose session rang the bell while in the background.
    @Published private(set) var attention: Set<String> = []
    /// Set by the notch to ask the main window to select and front a folder.
    @Published var requestedFolder: String?
    private var sessions: [String: TerminalSession] = [:]
    private var focusedFolder: String?

    func open(folder: String) {
        guard sessions[folder] == nil else { return }
        sessions[folder] = makeSession(folder: folder)
        openOrder.append(folder)
    }

    func controller(for folder: String) -> TerminiTerminalController? {
        sessions[folder]?.controller
    }

    func isOpen(_ folder: String) -> Bool { sessions[folder] != nil }

    /// Type a command into the folder's shell and run it (one-touch resume).
    func run(_ command: String, in folder: String) {
        sessions[folder]?.send(Data((command + "\r").utf8))
    }

    func close(folder: String) {
        sessions[folder]?.stop()
        sessions[folder] = nil
        openOrder.removeAll { $0 == folder }
        attention.remove(folder)
    }

    /// The folder currently on screen. A bell there is not an interruption, so
    /// no chime, and any pending attention on it clears.
    func focus(_ folder: String?) {
        focusedFolder = folder
        if let folder { attention.remove(folder) }
    }

    /// Dismiss a session's attention alert without switching to it.
    func clearAttention(_ folder: String) { attention.remove(folder) }

    func folderName(_ folder: String) -> String { (folder as NSString).lastPathComponent }

    func agentLabel(for kinds: [AgentKind]) -> String? {
        if kinds.contains(.claude) { return "claude" }
        if kinds.contains(.codex) { return "codex" }
        return nil
    }

    // MARK: - internals

    private func handleBell(_ folder: String) {
        guard focusedFolder != folder else { return }   // you are already looking at it
        attention.insert(folder)
        Chime.fire(folderName: folderName(folder))
    }

    private func makeSession(folder: String) -> TerminalSession {
        let fm = FileManager.default
        let readable = fm.isReadableFile(atPath: folder)
        if readable { noAccess.remove(folder) } else { noAccess.insert(folder) }
        let dir = readable ? URL(fileURLWithPath: folder) : fm.homeDirectoryForCurrentUser
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        let spec = TerminiProcessSpec(
            executableURL: URL(fileURLWithPath: shell),
            arguments: ["-l"],
            environment: ProcessInfo.processInfo.environment,
            workingDirectoryURL: dir)

        let session = TerminalSession(spec: spec)
        session.onBell = { [weak self] in self?.handleBell(folder) }
        session.start()
        return session
    }
}
