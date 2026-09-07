import SwiftUI
import SessionEngine
import Termini

struct ContentView: View {
    @StateObject private var model = SessionListModel()
    @StateObject private var terminals = TerminalManager()
    @StateObject private var store = WorkspaceStore()
    @State private var selected: String?   // selected session's folder
    @State private var showingSave = false
    @State private var newWorkspaceName = ""
    @State private var gridMode = false
    @State private var gridColumns = 2   // 2 = 2x2, 3 = 3x3, 4 = 4x4
    @State private var openedWhileLive: Set<String> = []   // was live elsewhere when opened
    @State private var pickerFolder: String?
    @State private var pickerSessions: [SessionRecord] = []

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                workspacesSection
                sessionSection("Live", .live)
                sessionSection("Warm", .warm)
                sessionSection("Cold", .cold)
                serverSection
            }
            .listStyle(.sidebar)
            .navigationTitle("Deck")
            .frame(minWidth: 260)
            .toolbar {
                if model.idleCount > 0 {
                    ToolbarItem {
                        Button {
                            Task { await model.sleepAllIdle() }
                        } label: {
                            Label("Sleep \(model.idleCount) idle", systemImage: "moon.zzz")
                        }
                        .help("Stop all idle agents to reclaim RAM (resumable later)")
                    }
                }
                ToolbarItem {
                    Button {
                        newWorkspaceName = ""
                        showingSave = true
                    } label: {
                        Image(systemName: "bookmark")
                    }
                    .disabled(terminals.openOrder.isEmpty)
                    .help("Save the open tabs as a workspace")
                }
                ToolbarItem {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.loading)
                    .help("Refresh now")
                }
            }
            .alert("Save workspace", isPresented: $showingSave) {
                TextField("Name", text: $newWorkspaceName)
                Button("Save") { store.save(name: newWorkspaceName, folders: terminals.openOrder) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save the \(terminals.openOrder.count) open tab(s) as a named workspace you can reopen in one click.")
            }
        } detail: {
            VStack(spacing: 0) {
                detailControls
                Divider()
                if gridMode {
                    gridView
                } else {
                    if !terminals.openOrder.isEmpty {
                        TabStrip(terminals: terminals, selected: $selected)
                        Divider()
                    }
                    detailBody
                }
            }
        }
        .onChange(of: selected) { _, newValue in
            guard let folder = newValue, !terminals.isOpen(folder) else { return }
            // Capture "already live elsewhere" before we spawn our own resume.
            if model.isLive(folder) { openedWhileLive.insert(folder) }
            let kinds = model.entries.first(where: { $0.folder == folder })?.kinds ?? []
            guard kinds.contains(.claude) else {
                terminals.open(folder: folder, kinds: kinds)   // codex / shell: no picker
                return
            }
            // Claude: if the folder has multiple saved conversations, ask which.
            Task {
                let sessions = await Task.detached { History.claudeSessions(inFolder: folder) }.value
                guard selected == folder, !terminals.isOpen(folder) else { return }
                if sessions.count > 1 {
                    pickerSessions = sessions
                    pickerFolder = folder
                } else {
                    terminals.open(folder: folder, kinds: kinds)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { pickerFolder != nil },
            set: { if !$0 { pickerFolder = nil } })
        ) {
            if let folder = pickerFolder {
                ResumePicker(
                    folder: folder,
                    sessions: pickerSessions,
                    onPick: { id in
                        terminals.open(folder: folder, command: "claude --resume \(id)")
                        pickerFolder = nil
                    },
                    onMostRecent: {
                        terminals.open(folder: folder, kinds: [.claude])
                        pickerFolder = nil
                    },
                    onCancel: {
                        selected = nil
                        pickerFolder = nil
                    })
            }
        }
        .onChange(of: terminals.openOrder) { _, folders in
            store.updateLastOpen(folders)
        }
        .task {
            await model.refresh()
            model.startAutoRefresh()
        }
    }

    private func openFolders(_ folders: [String]) {
        for folder in folders {
            let kinds = model.entries.first(where: { $0.folder == folder })?.kinds ?? [.claude]
            terminals.open(folder: folder, kinds: kinds)
        }
        selected = folders.last
        if folders.count > 1 { gridMode = true }   // tile a multi-session workspace
    }

    @ViewBuilder
    private var workspacesSection: some View {
        if !store.workspaces.isEmpty || !store.lastOpen.isEmpty {
            Section("Workspaces") {
                if !store.lastOpen.isEmpty {
                    Button {
                        openFolders(store.lastOpen)
                    } label: {
                        Label("Last session (\(store.lastOpen.count))", systemImage: "clock.arrow.circlepath")
                    }
                }
                ForEach(store.workspaces) { ws in
                    Button {
                        openFolders(ws.folders)
                    } label: {
                        Label("\(ws.name) (\(ws.folders.count))", systemImage: "square.stack.3d.up")
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) { store.delete(ws) }
                    }
                }
            }
        }
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
                        openedWhileLive.remove(folder)
                        selected = terminals.openOrder.last
                    }
                    .help("Stop this terminal and reclaim its RAM (resumable later)")
                }
                .padding(8)
                Divider()
                if openedWhileLive.contains(folder) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle").foregroundStyle(.blue)
                        Text("A session for this project is already running elsewhere. This tab is a separate resume, not that live process.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.blue.opacity(0.10))
                    Divider()
                }
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

    private var detailControls: some View {
        HStack(spacing: 12) {
            Picker("", selection: $gridMode) {
                Text("Tabs").tag(false)
                Text("Grid").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            .labelsHidden()

            if gridMode {
                Picker("", selection: $gridColumns) {
                    Text("2×2").tag(2)
                    Text("3×3").tag(3)
                    Text("4×4").tag(4)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
                .labelsHidden()
                Text("\(terminals.openOrder.count) open")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(6)
    }

    @ViewBuilder
    private var gridView: some View {
        if terminals.openOrder.isEmpty {
            ContentUnavailableView(
                "No open sessions",
                systemImage: "square.grid.2x2",
                description: Text("Open sessions from the sidebar (or a workspace) to tile them here."))
        } else {
            GeometryReader { geo in
                let cols = gridColumns
                let rows = max(1, Int(ceil(Double(terminals.openOrder.count) / Double(cols))))
                let spacing: CGFloat = 8
                let cellW = (geo.size.width - spacing * CGFloat(cols + 1)) / CGFloat(cols)
                let cellH = max(140, (geo.size.height - spacing * CGFloat(rows + 1)) / CGFloat(rows))
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(cellW), spacing: spacing), count: cols),
                        spacing: spacing
                    ) {
                        ForEach(terminals.openOrder, id: \.self) { folder in
                            GridCell(folder: folder, terminals: terminals) {
                                selected = folder
                                gridMode = false
                            }
                            .frame(width: cellW, height: cellH)
                        }
                    }
                    .padding(spacing)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionSection(_ title: String, _ status: SessionStatus) -> some View {
        let items = model.entries(status)
        Section("\(title) (\(items.count))") {
            ForEach(items) { entry in
                SessionRow(entry: entry, isOpen: terminals.isOpen(entry.folder))
                    .tag(entry.folder)
                    .contextMenu {
                        if entry.status == .live {
                            Button("Sleep (reclaim RAM)") {
                                Task { await model.sleepSession(folder: entry.folder) }
                            }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var serverSection: some View {
        if !model.servers.isEmpty {
            Section("Dev servers (\(model.servers.count))") {
                ForEach(model.servers) { server in
                    HStack(spacing: 8) {
                        Image(systemName: "server.rack").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(server.command) :\(server.port)").lineLimit(1)
                            Text("\(server.folderName) · up \(server.uptimeText)")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Button {
                            Task { await model.killServer(server) }
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                        .help("Kill this server")
                    }
                }
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

/// Chooser shown when a folder has more than one saved Claude conversation.
struct ResumePicker: View {
    let folder: String
    let sessions: [SessionRecord]
    let onPick: (String) -> Void
    let onMostRecent: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Resume which session?").font(.headline).padding([.top, .horizontal])
            Text((folder as NSString).lastPathComponent)
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal).padding(.bottom, 8)
            Divider()
            List(sessions) { session in
                Button {
                    onPick(session.sessionId)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.preview.isEmpty
                             ? "session \(String(session.sessionId.prefix(8)))"
                             : session.preview)
                            .lineLimit(2)
                        Text(relative(session.lastActivity))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Divider()
            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                Spacer()
                Button("Continue most recent") { onMostRecent() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 440)
    }

    private func relative(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 3600 { return "\(max(1, s / 60))m ago" }
        if s < 86400 { return "\(s / 3600)h ago" }
        return "\(s / 86400)d ago"
    }
}

/// One tile in the grid: a live libghostty terminal with a compact header.
struct GridCell: View {
    let folder: String
    @ObservedObject var terminals: TerminalManager
    let onFocus: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(terminals.folderName(folder)).font(.caption).lineLimit(1)
                Spacer()
                Button(action: onFocus) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 9))
                }
                .buttonStyle(.plain).help("Focus this session")
                Button { terminals.close(folder: folder) } label: {
                    Image(systemName: "xmark").font(.system(size: 9))
                }
                .buttonStyle(.plain).help("Sleep this terminal")
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            if let controller = terminals.controller(for: folder) {
                TerminiTerminalView(controller: controller, appearance: .default)
            } else {
                Color.black
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
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
