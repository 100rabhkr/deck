import SwiftUI
import AppKit

enum NotchEdge: String { case top, right, bottom }

/// Compact always-on readout for the side notch. Calm at rest; when a
/// background session needs you it turns amber and lists them, click to jump.
struct NotchView: View {
    let edge: NotchEdge
    @ObservedObject var terminals = TerminalManager.shared
    @ObservedObject var model = SessionListModel.shared

    private var waiting: [String] { Array(terminals.attention).sorted() }
    private var liveCount: Int { model.liveAgents.count }
    private var idleCount: Int { model.idleCount }
    private var ramGB: Double { Double(model.liveAgents.reduce(0) { $0 + $1.rssMB }) / 1024.0 }

    var body: some View {
        layout {
            if waiting.isEmpty {
                Label("\(liveCount)", systemImage: "circle.fill")
                    .foregroundStyle(.green).font(.caption)
                Text("\(idleCount) idle").font(.caption2).foregroundStyle(.secondary)
                Text(String(format: "%.1f GB", ramGB)).font(.caption2).foregroundStyle(.secondary)
            } else {
                ForEach(waiting.prefix(edge == .right ? 4 : 3), id: \.self) { folder in
                    Button { jump(folder) } label: {
                        Label(terminals.folderName(folder), systemImage: "bell.fill")
                            .font(.caption).foregroundStyle(.orange).lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(waiting.isEmpty ? Color.secondary.opacity(0.25) : Color.orange, lineWidth: waiting.isEmpty ? 1 : 2))
        .contentShape(Capsule())
        .onTapGesture { NSApp.activate(ignoringOtherApps: true) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func layout<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        if edge == .right {
            VStack(spacing: 6) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    private func jump(_ folder: String) {
        terminals.requestedFolder = folder
        NSApp.activate(ignoringOtherApps: true)
    }
}
