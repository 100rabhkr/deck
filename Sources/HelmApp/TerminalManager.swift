import Foundation
import Termini

/// Vends one live terminal per folder and keeps it alive as you switch tabs.
/// Opening a session starts a login shell in that folder; switching away leaves
/// it running (a "warm" tab); `sleep` stops it to reclaim RAM.
@MainActor
final class TerminalManager: ObservableObject {
    private var workspaces: [String: TerminiLocalPTYWorkspace] = [:]

    func workspace(for folder: String) -> TerminiLocalPTYWorkspace {
        if let existing = workspaces[folder] { return existing }

        let fm = FileManager.default
        let dir = fm.fileExists(atPath: folder)
            ? URL(fileURLWithPath: folder)
            : fm.homeDirectoryForCurrentUser
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        let spec = TerminiProcessSpec(
            executableURL: URL(fileURLWithPath: shell),
            arguments: ["-l"],
            environment: ProcessInfo.processInfo.environment,
            workingDirectoryURL: dir)

        let ws = TerminiLocalPTYWorkspace(processSpec: spec)
        ws.start()
        workspaces[folder] = ws
        return ws
    }

    /// Stop and forget a folder's terminal (reclaim its RAM). Resumable later.
    func sleep(folder: String) {
        workspaces[folder]?.stop()
        workspaces[folder] = nil
    }

    var openFolders: Set<String> { Set(workspaces.keys) }
}
