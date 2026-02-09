import SwiftUI

@main
struct OctopusSchedulerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                configManager: appDelegate.configManager,
                schedulerEngine: appDelegate.schedulerEngine,
                notificationService: appDelegate.notificationService
            )
        }
    }
}
