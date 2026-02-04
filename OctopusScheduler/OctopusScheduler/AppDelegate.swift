import AppKit
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        configManager.load()

        // Configure services
        let config = configManager.config ?? .defaultConfig
        logService.configure(logDirectory: config.globalOptions.logDirectory)
        notificationService.configure(enabled: config.globalOptions.showNotifications)
        configureLaunchAtLogin(enabled: config.globalOptions.launchAtLogin)

        schedulerEngine.configure(
            configManager: configManager,
            promptLoader: promptLoader,
            claudeAutomator: claudeAutomator,
            notificationService: notificationService,
            logService: logService
        )
        schedulerEngine.start()
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

        // Schedule items
        let schedules = configManager.config?.schedules ?? []
        if schedules.isEmpty {
            let item = NSMenuItem(title: "No schedules configured", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for schedule in schedules {
                let title = "\(schedule.enabled ? "✓ " : "   ")\(schedule.name) (\(schedule.schedule.time))"
                let item = NSMenuItem(title: title, action: #selector(toggleSchedule(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = schedule.id
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
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Reload config
        let reloadItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
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

    @objc private func reloadConfig() {
        configManager.load()
        schedulerEngine.restart()
        rebuildMenu()
        logService.log("Config reloaded")
    }
}
