import AppKit
import Combine
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    let configManager = ConfigManager()
    let schedulerEngine = SchedulerEngine()
    private let claudeAutomator = ClaudeAutomator()
    private let promptLoader = PromptLoader()
    private let notificationService = NotificationService()
    private let logService = LogService()
    private let slackNotifier = SlackNotifier()
    private let bridgeService = BridgeService()
    private let httpServer = SchedulerHTTPServer()
    private var bridgeCancellable: AnyCancellable?
    private var updateAvailableVersion: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        configManager.load()

        // Configure services
        let config = configManager.config ?? .defaultConfig
        logService.configure(logDirectory: config.globalOptions.logDirectory)
        notificationService.configure(enabled: config.globalOptions.showNotifications)
        slackNotifier.configure(slackConfig: config.slack)
        configureLaunchAtLogin(enabled: config.globalOptions.launchAtLogin)

        schedulerEngine.configure(
            configManager: configManager,
            promptLoader: promptLoader,
            claudeAutomator: claudeAutomator,
            notificationService: notificationService,
            logService: logService,
            slackNotifier: slackNotifier
        )
        schedulerEngine.start()

        // Bridge service
        bridgeService.configure(bridgeUrl: config.bridge?.url)
        bridgeService.startPolling()
        bridgeCancellable = bridgeService.objectWillChange.sink(receiveValue: { [weak self] in
            DispatchQueue.main.async { self?.rebuildMenu() }
        })

        // HTTP server
        if let httpConfig = config.http, httpConfig.enabled {
            httpServer.start(config: httpConfig, schedulerEngine: schedulerEngine, configManager: configManager, logService: logService)
        }

        // Silent update check
        Task {
            await UpdateChecker.shared.checkForUpdates()
            let version = await UpdateChecker.shared.updateAvailable ? await UpdateChecker.shared.latestVersion : nil
            await MainActor.run {
                self.updateAvailableVersion = version
                self.rebuildMenu()
            }
        }

        logService.log("OctopusScheduler launched")
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🐙"
        }
        rebuildMenu()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: ConfigManager.configDidChangeNotification,
            object: nil
        )
    }

    private func configureLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    try service.register()
                    logService.log("Launch at Login enabled")
                } else {
                    try service.unregister()
                    logService.log("Launch at Login disabled")
                }
            } catch {
                logService.error("Launch at Login failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func configDidChange() {
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let config = configManager.config
        let schedules = config?.schedules ?? []

        // Header
        let version = config?.version ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        let headerItem = NSMenuItem(title: "OCTOPUS Scheduler v\(version)", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        // Connection status (live)
        let statusText: String
        switch bridgeService.status {
        case .connected:
            statusText = "🟢 Connected to Bridge"
        case .disconnected:
            statusText = "🔴 Bridge disconnected"
        case .notConfigured:
            statusText = "⚪ Bridge not configured"
        }
        let bridgeStatusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        bridgeStatusItem.isEnabled = false
        menu.addItem(bridgeStatusItem)

        menu.addItem(NSMenuItem.separator())

        // Active workflows
        let active = schedules.filter { $0.enabled }
        let paused = schedules.filter { !$0.enabled }

        if active.isEmpty && paused.isEmpty {
            let item = NSMenuItem(title: "No schedules configured", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            if !active.isEmpty {
                let activeHeader = NSMenuItem(title: "▶ Active Workflows (\(active.count))", action: nil, keyEquivalent: "")
                activeHeader.isEnabled = false
                menu.addItem(activeHeader)
                for schedule in active {
                    let nextStr = formatNextFire(schedule)
                    let item = NSMenuItem(title: "    \(schedule.name) — next: \(nextStr)", action: #selector(toggleSchedule(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = schedule.id
                    menu.addItem(item)
                }
            }

            if !paused.isEmpty {
                if !active.isEmpty { menu.addItem(NSMenuItem.separator()) }
                let pausedHeader = NSMenuItem(title: "⏸ Paused (\(paused.count))", action: nil, keyEquivalent: "")
                pausedHeader.isEnabled = false
                menu.addItem(pausedHeader)
                for schedule in paused {
                    let item = NSMenuItem(title: "    \(schedule.name) — paused", action: #selector(toggleSchedule(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = schedule.id
                    menu.addItem(item)
                }
            }
        }

        // Peers Online
        if !bridgeService.peers.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let peersHeader = NSMenuItem(title: "👥 Peers Online (\(bridgeService.peers.count))", action: nil, keyEquivalent: "")
            peersHeader.isEnabled = false
            menu.addItem(peersHeader)
            for peer in bridgeService.peers {
                let item = NSMenuItem(title: "    \(peer.peerId)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Run Now submenu
        let runNowItem = NSMenuItem(title: "Run Now", action: nil, keyEquivalent: "")
        let runNowSubmenu = NSMenu()
        for schedule in schedules {
            let item = NSMenuItem(title: schedule.name, action: #selector(runNow(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = schedule.id
            runNowSubmenu.addItem(item)
        }
        if schedules.isEmpty {
            let item = NSMenuItem(title: "No prompts available", action: nil, keyEquivalent: "")
            item.isEnabled = false
            runNowSubmenu.addItem(item)
        }
        runNowItem.submenu = runNowSubmenu
        menu.addItem(runNowItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "⚙ Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // View Logs
        let logsItem = NSMenuItem(title: "📋 View Logs...", action: #selector(viewLogs), keyEquivalent: "")
        logsItem.target = self
        menu.addItem(logsItem)

        // Sync Now
        let syncItem = NSMenuItem(title: "🔄 Sync Now", action: #selector(syncNow), keyEquivalent: "r")
        syncItem.target = self
        menu.addItem(syncItem)

        // Check for Updates
        let updateTitle = updateAvailableVersion != nil
            ? "⬆ Update to v\(updateAvailableVersion!)..."
            : "Check for Updates..."
        let updateItem = NSMenuItem(title: updateTitle, action: #selector(checkForUpdates), keyEquivalent: "u")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit OCTOPUS Scheduler", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    private func formatNextFire(_ schedule: ScheduleConfig) -> String {
        guard let fireDate = schedule.nextFireDate() else { return "unknown" }
        let calendar = Calendar.current

        if calendar.isDateInToday(fireDate) {
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return "today \(fmt.string(from: fireDate))"
        } else if calendar.isDateInTomorrow(fireDate) {
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return "tomorrow \(fmt.string(from: fireDate))"
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEEE h:mm a"
            return fmt.string(from: fireDate)
        }
    }

    @objc private func viewLogs() {
        let logDir = configManager.config?.globalOptions.logDirectory ?? "~/.octopus-scheduler/logs"
        let resolved = (logDir as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: resolved, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: resolved, isDirectory: true))
    }

    @objc private func toggleSchedule(_ sender: NSMenuItem) {
        guard let scheduleId = sender.representedObject as? String else { return }
        configManager.toggleSchedule(id: scheduleId)
        schedulerEngine.restart()
        rebuildMenu()
    }

    @objc private func runNow(_ sender: NSMenuItem) {
        guard let scheduleId = sender.representedObject as? String else { return }
        schedulerEngine.executeNow(scheduleId: scheduleId)
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func syncNow() {
        configManager.load()
        let config = configManager.config ?? .defaultConfig
        bridgeService.configure(bridgeUrl: config.bridge?.url)
        bridgeService.syncNow()
        schedulerEngine.restart()
        rebuildMenu()
        logService.log("Sync completed")
    }

    private func makeAppIcon() -> NSImage {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 48)]
        let str = NSAttributedString(string: "🐙", attributes: attrs)
        let strSize = str.size()
        str.draw(at: NSPoint(x: (size.width - strSize.width) / 2, y: (size.height - strSize.height) / 2))
        image.unlockFocus()
        return image
    }

    @objc private func checkForUpdates() {
        Task { @MainActor in
            await UpdateChecker.shared.checkForUpdates()
            let checker = UpdateChecker.shared

            let alert = NSAlert()
            alert.icon = makeAppIcon()
            if checker.updateAvailable, let version = checker.latestVersion {
                alert.messageText = "Update Available"
                alert.informativeText = "OctopusScheduler v\(version) is available.\nYou're running v\(checker.currentVersion)."
                alert.addButton(withTitle: "Download")
                alert.addButton(withTitle: "Later")
                if alert.runModal() == .alertFirstButtonReturn, let url = checker.downloadURL {
                    NSWorkspace.shared.open(url)
                }
            } else {
                alert.messageText = "You're up to date"
                alert.informativeText = "OctopusScheduler v\(checker.currentVersion) is the latest version."
                alert.runModal()
            }
        }
    }
}
