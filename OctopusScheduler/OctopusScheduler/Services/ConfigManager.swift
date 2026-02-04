import Foundation

class ConfigManager: ObservableObject {
    static let configDidChangeNotification = Notification.Name("ConfigManagerDidChange")
    private static let configPath = ("~/.octopus-scheduler/config.json" as NSString).expandingTildeInPath

    @Published var config: AppConfig?

    func load() {
        let path = Self.configPath
        guard FileManager.default.fileExists(atPath: path),
              let data = FileManager.default.contents(atPath: path) else {
            print("[OctopusScheduler] No config found at \(path)")
            config = nil
            return
        }

        do {
            let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
            config = decoded
            print("[OctopusScheduler] Loaded config with \(decoded.schedules.count) schedule(s)")
            NotificationCenter.default.post(name: Self.configDidChangeNotification, object: nil)
        } catch {
            print("[OctopusScheduler] Failed to parse config: \(error)")
            config = nil
        }
    }

    func save() {
        guard let config = config else { return }
        let path = Self.configPath
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: URL(fileURLWithPath: path))
            print("[OctopusScheduler] Config saved")
        } catch {
            print("[OctopusScheduler] Failed to save config: \(error)")
        }
    }

    func toggleSchedule(id: String) {
        guard let index = config?.schedules.firstIndex(where: { $0.id == id }) else { return }
        config?.schedules[index].enabled.toggle()
        save()
        NotificationCenter.default.post(name: Self.configDidChangeNotification, object: nil)
    }
}
