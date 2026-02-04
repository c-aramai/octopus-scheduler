import Foundation

struct AppConfig: Codable {
    var version: String
    var promptsDirectory: String
    var schedules: [ScheduleConfig]
    var globalOptions: GlobalOptions

    static let defaultConfig = AppConfig(
        version: "1.0",
        promptsDirectory: "~/ARAMAI/prompts/scheduled",
        schedules: [],
        globalOptions: GlobalOptions(launchAtLogin: false, showNotifications: true, logDirectory: "~/.octopus-scheduler/logs")
    )

    /// Resolves the prompts directory path, expanding ~ to the home directory.
    var resolvedPromptsDirectory: String {
        (promptsDirectory as NSString).expandingTildeInPath
    }
}

struct GlobalOptions: Codable {
    var launchAtLogin: Bool
    var showNotifications: Bool
    var logDirectory: String?
}
