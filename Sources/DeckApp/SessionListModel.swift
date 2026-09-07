import Foundation
import SessionEngine

/// Loads the session list, live agents and dev servers off the main thread and
/// publishes them. Discovery is native (libproc) now, so it is cheap enough to
/// poll on a timer.
@MainActor
final class SessionListModel: ObservableObject {
    @Published var entries: [HistoryEntry] = []
    @Published var liveAgents: [LiveAgent] = []
    @Published var servers: [DevServer] = []
    @Published var loading = false

    /// RAM below which a live agent is treated as idle (from Settings).
    var idleThresholdMB = 40

    private var autoRefresh: Task<Void, Never>?

    func refresh() async {
        loading = true
        let snapshot = await Task.detached(priority: .userInitiated) {
            (entries: History.entries(includeContext: false),
             live: Discovery.liveAgents(),
             servers: Discovery.devServers())
        }.value
        entries = snapshot.entries
        liveAgents = snapshot.live
        servers = snapshot.servers
        loading = false
    }

    func startAutoRefresh(every seconds: Double = 4) {
        autoRefresh?.cancel()
        autoRefresh = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(seconds))
                await self?.refresh()
            }
        }
    }

    func stopAutoRefresh() { autoRefresh?.cancel() }

    // MARK: - Derived views

    func entries(_ status: SessionStatus) -> [HistoryEntry] {
        entries.filter { $0.status == status }
    }

    var idleCount: Int { liveAgents.filter { $0.rssMB < idleThresholdMB }.count }

    func isLive(_ folder: String) -> Bool {
        liveAgents.contains { $0.folder == folder }
    }

    // MARK: - Actions

    /// SIGTERM the live agent(s) running in a folder (reclaim RAM, resumable).
    func sleepSession(folder: String) async {
        let pids = liveAgents.filter { $0.folder == folder }.map { $0.pid }
        await Task.detached { pids.forEach { Discovery.sleepAgent(pid: $0) } }.value
        await refresh()
    }

    /// SIGTERM every idle live agent at once.
    func sleepAllIdle() async {
        let pids = liveAgents.filter { $0.rssMB < idleThresholdMB }.map { $0.pid }
        await Task.detached { pids.forEach { Discovery.sleepAgent(pid: $0) } }.value
        await refresh()
    }

    func killServer(_ server: DevServer) async {
        let pid = server.pid
        _ = await Task.detached { Discovery.stopServer(pid: pid) }.value
        await refresh()
    }
}
