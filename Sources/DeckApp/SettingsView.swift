import SwiftUI
import Termini

/// Standard macOS Settings window (⌘,). Every control is @AppStorage-backed and
/// shared with the main view, so changes apply live.
struct SettingsView: View {
    @AppStorage("deck.theme") private var themeName = ""
    @AppStorage("deck.fontSize") private var fontSize = 13.0
    @AppStorage("deck.fontFamily") private var fontFamily = ""
    @AppStorage("deck.refreshSeconds") private var refreshSeconds = 4.0
    @AppStorage("deck.gridDefault") private var gridDefault = 1
    @AppStorage("deck.idleMB") private var idleMB = 40
    @AppStorage("deck.restoreLast") private var restoreLast = false
    @AppStorage("deck.claudeResume") private var claudeResume = "claude --continue"
    @AppStorage("deck.codexResume") private var codexResume = "codex resume --last"
    @AppStorage("deck.chime") private var chime = false
    @AppStorage("deck.notify") private var notify = true
    @AppStorage("deck.chimeSound") private var chimeSound = "Beep"
    @AppStorage("deck.notch") private var notch = true
    @AppStorage("deck.notchEdge") private var notchEdge = "top"

    var body: some View {
        TabView {
            appearanceTab.tabItem { Label("Appearance", systemImage: "paintpalette") }
            behaviourTab.tabItem { Label("Behaviour", systemImage: "slider.horizontal.3") }
            agentsTab.tabItem { Label("Agents", systemImage: "terminal") }
            chimeTab.tabItem { Label("Chime", systemImage: "bell") }
            notchTab.tabItem { Label("Notch", systemImage: "menubar.rectangle") }
        }
        .frame(width: 480, height: 300)
    }

    private var notchTab: some View {
        Form {
            Toggle("Show the side notch", isOn: $notch)
            Picker("Pin to", selection: $notchEdge) {
                Text("Top").tag("top")
                Text("Right").tag("right")
                Text("Bottom").tag("bottom")
            }
            .pickerStyle(.segmented)
            .disabled(!notch)
            Text("A small always-on pill showing your fleet: it turns amber and names any session waiting on you. Click a name to jump to it.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var chimeTab: some View {
        Form {
            Toggle("Chime when a background session needs you", isOn: $chime)
            Picker("Sound", selection: $chimeSound) {
                ForEach(["Beep", "Ping", "Glass", "Submarine", "Funk", "Hero", "Tink"], id: \.self) {
                    Text($0).tag($0)
                }
            }
            .disabled(!chime)
            Toggle("Also show a notification", isOn: $notify).disabled(!chime)
            Text("Deck watches each session's terminal bell. When one you are not looking at rings, it lets you know.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var appearanceTab: some View {
        Form {
            Picker("Theme", selection: $themeName) {
                Text("Default").tag("")
                ForEach(TerminiTerminalTheme.presets) { Text($0.name).tag($0.name) }
            }
            HStack {
                Text("Font size")
                Slider(value: $fontSize, in: 9...24, step: 1)
                Text("\(Int(fontSize)) pt").monospacedDigit().foregroundStyle(.secondary)
            }
            TextField("Font family", text: $fontFamily, prompt: Text("blank = default"))
        }
        .padding(20)
    }

    private var behaviourTab: some View {
        Form {
            HStack {
                Text("Auto-refresh")
                Slider(value: $refreshSeconds, in: 2...30, step: 1)
                Text("\(Int(refreshSeconds))s").monospacedDigit().foregroundStyle(.secondary)
            }
            Picker("Default layout", selection: $gridDefault) {
                Text("Single").tag(1)
                Text("2×2").tag(2)
                Text("3×3").tag(3)
                Text("4×4").tag(4)
            }
            Stepper("Idle threshold: \(idleMB) MB", value: $idleMB, in: 10...200, step: 10)
            Toggle("Restore last session on launch", isOn: $restoreLast)
        }
        .padding(20)
    }

    private var agentsTab: some View {
        Form {
            TextField("Claude resume", text: $claudeResume)
            TextField("Codex resume", text: $codexResume)
            Text("Injected into the shell when you press Resume.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
