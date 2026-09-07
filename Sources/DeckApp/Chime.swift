import AppKit
import UserNotifications

/// Plays the attention chime and posts a notification when a background session
/// rings the bell. Reads its on/off + sound from the same defaults the Settings
/// window writes.
enum Chime {
    static func requestAuthorizationIfPossible() {
        guard Bundle.main.bundleIdentifier != nil else { return }  // needs a bundle
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func fire(folderName: String) {
        let d = UserDefaults.standard
        guard (d.object(forKey: "deck.chime") as? Bool) ?? true else { return }

        // Sound
        let soundName = d.string(forKey: "deck.chimeSound") ?? ""
        if soundName.isEmpty || soundName == "Beep" {
            NSSound.beep()
        } else if let sound = NSSound(named: soundName) {
            sound.play()
        } else {
            NSSound.beep()
        }

        // Notification (best-effort, only in a bundled app)
        guard Bundle.main.bundleIdentifier != nil,
              (d.object(forKey: "deck.notify") as? Bool) ?? true else { return }
        let content = UNMutableNotificationContent()
        content.title = folderName
        content.body = "A session needs your attention."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
