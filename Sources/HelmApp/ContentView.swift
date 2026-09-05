import SwiftUI
import SessionEngine
import Termini

struct ContentView: View {
    @StateObject private var model = SessionListModel()
    @StateObject private var terminals = TerminalManager()
    @State private var selected: String?   // selected session's folder

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                sessionSection("Live", .live)
                sessionSection("Warm", .warm)
                sessionSection("Cold", .cold)
            }
            .listStyle(.sidebar)
            .navigationTitle("Helm")
            .frame(minWidth: 260)
            .toolbar {
                ToolbarItem {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: model.loading ? "arrow.clockwise.circle" : "arrow.clockwise")
                    }
                    .disabled(model.loading)
                    .help("Refresh sessions")
                }
            }
        } detail: {
            if let folder = selected {
                TerminalTab(folder: folder, terminals: terminals)
                    .id(folder)   // rebind the surface when the selection changes
            } else {
                ContentUnavailableView(
                    "Select a session",
                    systemImage: "terminal",
                    description: Text("Pick a project on the left to open a terminal in its folder."))
            }
        }
        .task { await model.refresh() }
    }

    @ViewBuilder
    private func sessionSection(_ title: String, _ status: SessionStatus) -> some View {
        let items = model.entries(status)
        Section("\(title) (\(items.count))") {
            ForEach(items) { entry in
                SessionRow(entry: entry).tag(entry.folder)
            }
        }
    }
}

struct SessionRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.folderName).lineLimit(1)
                Text(entry.kinds.map { $0.rawValue }.joined(separator: "+"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
    }

    private var statusColor: Color {
        switch entry.status {
        case .live: return .green
        case .warm: return .yellow
        case .cold: return .gray
        }
    }
}

/// A single terminal tab: a libghostty surface running a shell in the folder.
struct TerminalTab: View {
    let folder: String
    @ObservedObject var terminals: TerminalManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "folder")
                Text(folder).font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                Spacer()
                Button("Sleep") { terminals.sleep(folder: folder) }
                    .help("Stop this terminal and reclaim its RAM")
            }
            .padding(8)
            Divider()
            TerminiTerminalView(controller: terminals.workspace(for: folder).controller,
                                appearance: .default)
        }
    }
}
