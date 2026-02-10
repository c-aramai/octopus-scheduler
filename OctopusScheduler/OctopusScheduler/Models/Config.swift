import Foundation

struct AppConfig: Codable {
    var version: String
    var peerId: String?
    var domain: String?
    var promptsDirectory: String
    var schedules: [ScheduleConfig]
    var globalOptions: GlobalOptions
    var bridge: BridgeConfig?
    var slack: SlackConfig?
    var http: HTTPConfig?
    var bridgeForward: BridgeForwardConfig?

    static let defaultConfig = AppConfig(
        version: "1.2.0",
        peerId: Host.current().localizedName,
        domain: "aramai.io",
        promptsDirectory: "~/ARAMAI/prompts/scheduled",
        schedules: [],
        globalOptions: GlobalOptions(launchAtLogin: false, showNotifications: true, logDirectory: "~/.octopus-scheduler/logs"),
        bridge: BridgeConfig(),
        slack: nil,
        http: nil
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
    var allowConcurrentExecutions: Bool?
    var claudeCLIPath: String?
}

struct BridgeConfig: Codable {
    var url: String = "https://octopus-bridge.vercel.app"
    var reconnectInterval: Int? = 10000
}

struct SlackConfig: Codable {
    var webhookUrl: String?
    var defaultChannel: String?
    var notifyOnComplete: Bool? = true
    var notifyOnFailure: Bool? = true
}

struct HTTPConfig: Codable {
    var enabled: Bool = false
    var port: Int = 19840
    var secret: String = ""
}

struct BridgeForwardConfig: Codable {
    var enabled: Bool = false
    var webhookSecret: String = ""
    var forwardEvents: [String]? = nil
    var slackChannel: String? = nil
}
