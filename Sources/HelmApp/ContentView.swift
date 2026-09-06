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
            .navigationTitle("Deck")
            .frame(minWidth: 260)
            .toolbar {
                ToolbarItem {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.loading)
                    .help("Refresh sessions")
                }
            }
        } detail: {
            VStack(spacing: 0) {
                if !terminals.openOrder.isEmpty {
                    TabStrip(terminals: terminals, selected: $selected)
                    Divider()
                }
                detailBody
            }
        }
        .onChange(of: selected) { _, newValue in
            guard let folder = newValue else { return }
            let kinds = model.entries.first(where: { $0.folder == folder })?.kinds ?? []
            terminals.open(folder: folder, kinds: kinds)
        }
        .task { await model.refresh() }
    }

    @ViewBuilder
    private var detailBody: some View {
        if let folder = selected, let controller = terminals.controller(for: folder) {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "folder")
                    Text(folder).font(.callout).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.head)
                    Spacer()
                    Button("Sleep") {
                        terminals.close(folder: folder)
                        selected = terminals.openOrder.last
                    }
                    .help("Stop this terminal and reclaim its RAM (resumable later)")
                }
                .padding(8)
                Divider()
                if terminals.noAccess.contains(folder) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        Text("No access to this folder (macOS privacy). Grant your terminal Full Disk Access in Privacy & Security, then reopen. Opened your home folder instead.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.yellow.opacity(0.12))
                    Divider()
                }
                TerminiTerminalView(controller: controller, appearance: .default)
                    .id(folder)
            }
        } else {
            ContentUnavailableView(
                "Select a session",
                systemImage: "terminal",
                description: Text("Pick a project on the left to resume it in a terminal."))
        }
    }

    @ViewBuilder
    private func sessionSection(_ title: String, _ status: SessionStatus) -> some View {
        let items = model.entries(status)
        Section("\(title) (\(items.count))") {
            ForEach(items) { entry in
                SessionRow(entry: entry, isOpen: terminals.isOpen(entry.folder))
                    .tag(entry.folder)
            }
        }
    }
}

struct SessionRow: View {
    let entry: HistoryEntry
    let isOpen: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.folderName).lineLimit(1)
                Text(entry.kinds.map { $0.rawValue }.joined(separator: "+"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isOpen {
                Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.tertiary)
                    .help("Open in a tab")
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

/// Chrome-style strip of open terminals.
struct TabStrip: View {
    @ObservedObject var terminals: TerminalManager
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(terminals.openOrder, id: \.self) { folder in
                    HStack(spacing: 6) {
                        Text(terminals.folderName(folder)).lineLimit(1)
                        Button {
                            terminals.close(folder: folder)
                            if selected == folder { selected = terminals.openOrder.last }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selected == folder ? Color.accentColor.opacity(0.30) : Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                    .onTapGesture { selected = folder }
                }
            }
            .padding(6)
        }
    }
}
