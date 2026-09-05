import Foundation

/// Minimal helper to run a system command and capture stdout.
///
/// The engine deliberately reads its state from the OS (process table, open
/// files) and from on-disk session stores, rather than requiring any agent to
/// cooperate. That keeps it agent-agnostic: anything that shows up as a process
/// or leaves a session file behind can be tracked.
enum Shell {
    /// Run an executable with arguments, return trimmed stdout ("" on failure).
    static func run(_ launchPath: String, _ args: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = args
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = Pipe()   // swallow stderr
        do {
            try proc.run()
        } catch {
            return ""
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
