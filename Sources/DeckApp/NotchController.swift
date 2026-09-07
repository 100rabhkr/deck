import AppKit
import SwiftUI

/// Manages the floating side-notch panel: an always-on-top, all-Spaces,
/// non-activating window pinned to a screen edge (top / right / bottom).
@MainActor
final class NotchController: ObservableObject {
    private var panel: NSPanel?

    func update(enabled: Bool, edge: String) {
        guard enabled else {
            panel?.orderOut(nil)
            panel = nil
            return
        }
        if panel == nil { makePanel() }
        reposition(edge: NotchEdge(rawValue: edge) ?? .top)
        panel?.orderFrontRegardless()
    }

    private func makePanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.isMovableByWindowBackground = false
        panel = p
    }

    private func reposition(edge: NotchEdge) {
        guard let p = panel, let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let size: NSSize = (edge == .right) ? NSSize(width: 64, height: 240)
                                            : NSSize(width: 320, height: 40)

        // Rehost the view so its layout matches the edge orientation.
        p.contentView = NSHostingView(rootView: NotchView(edge: edge))

        let origin: NSPoint
        switch edge {
        case .bottom: origin = NSPoint(x: vf.midX - size.width / 2, y: vf.minY + 6)
        case .right:  origin = NSPoint(x: vf.maxX - size.width - 6, y: vf.midY - size.height / 2)
        case .top:    origin = NSPoint(x: vf.midX - size.width / 2, y: vf.maxY - size.height - 6)
        }
        p.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
