import SwiftUI
import AppKit

// Run as a bare SwiftPM executable for now, so force a normal activation policy
// and bring the window forward. (A bundled .app comes at the packaging phase.)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }
}

@main
struct HelmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup("Deck") {
            ContentView()
        }
        .defaultSize(width: 1120, height: 700)
    }
}
