import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    private var enabled = true
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    func configure(enabled: Bool) {
        self.enabled = enabled
        if enabled {
            requestPermission()
        }
        checkAuthorizationStatus()
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error = error {
                print("[Notifications] Permission error: \(error.localizedDescription)")
            } else if !granted {
                print("[Notifications] Permission denied by user")
            }
            self?.checkAuthorizationStatus()
        }
    }
}
