import Foundation

/// Minimal helper to run a system command and capture stdout.
///
/// The engine reads its state from the OS (process table, open files) rather
/// than requiring any agent to cooperate. Kept deadlock-proof: stderr/stdin go
/// to /dev/null (an undrained stderr pipe can block the child and hang us), and
/// a timeout guarantees a hung child never freezes the caller.
enum Shell {
    static func run(_ launchPath: String, _ args: [String], timeout: TimeInterval = 10) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = args
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = FileHandle.nullDevice
        proc.standardInput = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            return ""
        }

        // Read stdout on a background queue so we can enforce a timeout.
        final class Box: @unchecked Sendable { var data = Data() }
        let box = Box()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            box.data = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        if group.wait(timeout: .now() + timeout) == .timedOut {
            proc.terminate()
            return ""
        }
        proc.waitUntilExit()
        return String(data: box.data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
