import Foundation

class ConfigManager: ObservableObject {
    static let configDidChangeNotification = Notification.Name("ConfigManagerDidChange")
    private static let configPath = ("~/.octopus-scheduler/config.json" as NSString).expandingTildeInPath

    @Published var config: AppConfig?

    private var fileWatchSource: DispatchSourceFileSystemObject?
    private var debounceTimer: Timer?

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

    // MARK: - File Watching

    func startWatching() {
        let fd = open(Self.configPath, O_EVTONLY)
        guard fd >= 0 else {
            print("[OctopusScheduler] Could not open config file for watching")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main
        )
        source.setEventHandler { [weak self] in self?.handleConfigFileChange() }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatchSource = source
        print("[OctopusScheduler] Watching config file for changes")
    }

    private func handleConfigFileChange() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.reloadIfValid()
        }
    }

    private func reloadIfValid() {
        let path = Self.configPath
        guard let data = FileManager.default.contents(atPath: path) else {
            print("[OctopusScheduler] Config file not readable during reload")
            return
        }
        do {
            let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
            config = decoded
            print("[OctopusScheduler] Config reloaded with \(decoded.schedules.count) schedule(s)")
            NotificationCenter.default.post(name: Self.configDidChangeNotification, object: nil)
        } catch {
            print("[OctopusScheduler] Config file has invalid JSON — keeping current config: \(error)")
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
