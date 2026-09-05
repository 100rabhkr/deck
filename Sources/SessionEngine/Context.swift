import Foundation

/// A one-line "what's happening here" summary for a folder, plus where it came
/// from. Context is pluggable so the engine never hard-depends on any one source
/// (in particular, not on a personal knowledge base that most users won't have).
public struct SessionContext: Sendable {
    public let summary: String
    public let source: String
}

public protocol ContextProvider: Sendable {
    var name: String { get }
    /// Whether this provider can run at all on this machine. Unavailable
    /// providers are dropped, so an absent source is a no-op, never an error.
    var isAvailable: Bool { get }
    func context(forFolder folder: String) -> String?
}

/// Universal default: the folder's most recent commit subject. Every developer
/// has git, so this works for everyone with zero setup.
public struct GitContextProvider: ContextProvider {
    public let name = "git"
    public init() {}
    public var isAvailable: Bool { FileManager.default.fileExists(atPath: "/usr/bin/git") }
    public func context(forFolder folder: String) -> String? {
        // Is it even a git repo? (cheap check avoids noisy errors)
        let top = Shell.run("/usr/bin/git", ["-C", folder, "rev-parse", "--show-toplevel"])
        guard !top.isEmpty else { return nil }
        let subject = Shell.run("/usr/bin/git", ["-C", folder, "log", "-1", "--pretty=%s"])
        return subject.isEmpty ? nil : "last commit: \(subject)"
    }
}

/// Optional bonus: reads the user's personal brain (`~/brain/sessions`). If that
/// directory does not exist, `isAvailable` is false and the provider is skipped
/// entirely, so nobody needs a brain for Helm to work.
public struct BrainContextProvider: ContextProvider {
    public let name = "brain"
    let root: String
    public init(root: String = NSString(string: "~/brain/sessions").expandingTildeInPath) {
        self.root = root
    }
    public var isAvailable: Bool { FileManager.default.fileExists(atPath: root) }

    public func context(forFolder folder: String) -> String? {
        guard isAvailable else { return nil }
        let token = (folder as NSString).lastPathComponent
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        guard token.count >= 3 else { return nil }

        // Find brain session files referencing this folder, newest first.
        let rg = "/opt/homebrew/bin/rg"
        guard FileManager.default.fileExists(atPath: rg) else { return nil }
        let hits = Shell.run(rg, ["-l", "-i", "--", token, root])
            .split(separator: "\n").map(String.init)
        guard !hits.isEmpty else { return nil }

        let fm = FileManager.default
        let newest = hits.max { a, b in
            let da = (try? fm.attributesOfItem(atPath: a))?[.modificationDate] as? Date ?? .distantPast
            let db = (try? fm.attributesOfItem(atPath: b))?[.modificationDate] as? Date ?? .distantPast
            return da < db
        }
        guard let file = newest, let content = try? String(contentsOfFile: file, encoding: .utf8) else { return nil }

        for line in content.split(separator: "\n") {
            if line.hasPrefix("topic:") {
                return line.dropFirst("topic:".count).trimmingCharacters(in: .whitespaces)
            }
        }
        for line in content.split(separator: "\n") where line.hasPrefix("# ") {
            return String(line.dropFirst(2))
        }
        return nil
    }
}

/// Tries providers in order and returns the first hit. Default order puts the
/// brain first (richer, when present) and git second (universal fallback).
public struct ContextResolver {
    let providers: [any ContextProvider]

    public init(providers: [any ContextProvider]? = nil) {
        let chain = providers ?? [BrainContextProvider(), GitContextProvider()]
        self.providers = chain.filter { $0.isAvailable }
    }

    public var activeProviderNames: [String] { providers.map { $0.name } }

    public func context(forFolder folder: String) -> SessionContext? {
        for p in providers {
            if let s = p.context(forFolder: folder) {
                return SessionContext(summary: s, source: p.name)
            }
        }
        return nil
    }
}
