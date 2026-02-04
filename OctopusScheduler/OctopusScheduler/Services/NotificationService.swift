import Foundation
import UserNotifications

class NotificationService {
    private var enabled = true

    func configure(enabled: Bool) {
        self.enabled = enabled
        if enabled {
            requestPermission()
        }
    }

    func notify(title: String, body: String) {
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] Failed to deliver: \(error.localizedDescription)")
            }
        }
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[Notifications] Permission error: \(error.localizedDescription)")
            } else if !granted {
                print("[Notifications] Permission denied by user")
            }
        }
    }
}
