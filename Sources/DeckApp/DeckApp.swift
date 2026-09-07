import SwiftUI
import AppKit
import Darwin

/// Raise the open-file limit for this process so the terminals (and agents like
/// Claude Code, which need well over the macOS 2560 default) that Deck spawns
/// inherit a sane limit, regardless of shell config.
func raiseFileDescriptorLimit(to target: rlim_t = 65536) {
    var lim = rlimit()
    guard getrlimit(RLIMIT_NOFILE, &lim) == 0, lim.rlim_cur < target else { return }
    // rlim_max "unlimited" is a very large value, so min() yields target there.
    lim.rlim_cur = min(target, lim.rlim_max)
    _ = setrlimit(RLIMIT_NOFILE, &lim)
}

// Run as a bare SwiftPM executable for now, so force a normal activation policy
// and bring the window forward. (A bundled .app comes at the packaging phase.)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        raiseFileDescriptorLimit()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }
}

@main
struct DeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup("Deck") {
            ContentView()
        }
        .defaultSize(width: 1120, height: 700)
    }
}
