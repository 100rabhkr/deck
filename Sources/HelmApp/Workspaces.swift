import Foundation

/// A named set of project folders you can open in one click.
struct Workspace: Codable, Identifiable, Sendable {
    var id: String { name }
    let name: String
    let folders: [String]
}

/// Persists workspaces and the last-open tab set to
/// ~/Library/Application Support/Deck/workspaces.json.
@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var workspaces: [Workspace] = []
    @Published private(set) var lastOpen: [String] = []

    private let fileURL: URL

    init() {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)) ?? FileManager.default.homeDirectoryForCurrentUser
        let dir = base.appendingPathComponent("Deck", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("workspaces.json")
        load()
    }

    private struct Persisted: Codable {
        var workspaces: [Workspace]
        var lastOpen: [String]
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let p = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        workspaces = p.workspaces
        lastOpen = p.lastOpen
    }

    private func persist() {
        let p = Persisted(workspaces: workspaces, lastOpen: lastOpen)
        if let data = try? JSONEncoder().encode(p) { try? data.write(to: fileURL) }
    }

    func save(name: String, folders: [String]) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, !folders.isEmpty else { return }
        workspaces.removeAll { $0.name == clean }
        workspaces.append(Workspace(name: clean, folders: folders))
        workspaces.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persist()
    }

    func delete(_ ws: Workspace) {
        workspaces.removeAll { $0.id == ws.id }
        persist()
    }

    func updateLastOpen(_ folders: [String]) {
        lastOpen = folders
        persist()
    }
}
