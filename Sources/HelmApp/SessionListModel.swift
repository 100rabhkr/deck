import Foundation
import SessionEngine

/// Loads the session list off the main thread (the engine shells out to
/// ps/lsof, which takes a few seconds) and publishes it to the UI.
@MainActor
final class SessionListModel: ObservableObject {
    @Published var entries: [HistoryEntry] = []
    @Published var loading = false

    func refresh() async {
        loading = true
        let loaded = await Task.detached(priority: .userInitiated) {
            History.entries(includeContext: false)
        }.value
        entries = loaded
        loading = false
    }

    func entries(_ status: SessionStatus) -> [HistoryEntry] {
        entries.filter { $0.status == status }
    }
}
