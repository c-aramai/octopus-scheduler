import AppKit
import Combine
import ServiceManagement
import SwiftUI

/// NSWindow subclass that accepts key events in menu-bar (agent) apps.
private class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

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
    private var claudeCancellable: AnyCancellable?
    private var updateAvailableVersion: String?
    private var settingsWindow: NSWindow?
    private var editorWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        configManager.load()
        configManager.startWatching()

        // Configure services
        let config = configManager.config ?? .defaultConfig
        logService.configure(logDirectory: config.globalOptions.logDirectory)
        notificationService.configure(enabled: config.globalOptions.showNotifications)
        slackNotifier.configure(slackConfig: config.slack)
        configureLaunchAtLogin(enabled: config.globalOptions.launchAtLogin)

        // Wire CLI path from config
        if let cliPath = config.globalOptions.claudeCLIPath {
            claudeAutomator.cliPath = cliPath
        }

        schedulerEngine.configure(
            configManager: configManager,
            promptLoader: promptLoader,
            claudeAutomator: claudeAutomator,
            notificationService: notificationService,
            logService: logService,
            slackNotifier: slackNotifier
        )

        // CLI setup wizard — show once if CLI not found
        if !FileManager.default.isExecutableFile(atPath: claudeAutomator.cliPath) {
            showCLISetupWizard()
        }

        schedulerEngine.start()

        // Bridge service
        bridgeService.configure(bridgeUrl: config.bridge?.url)
        bridgeService.startPolling()
        bridgeCancellable = bridgeService.objectWillChange.sink(receiveValue: { [weak self] in
            DispatchQueue.main.async { self?.rebuildMenu() }
        })

        // Claude health check
        claudeAutomator.checkHealth()
        claudeCancellable = claudeAutomator.objectWillChange.sink(receiveValue: { [weak self] in
            DispatchQueue.main.async { self?.rebuildMenu() }
        })
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.claudeAutomator.checkHealth()
        }

        // Sleep/wake recovery
        schedulerEngine.startWakeObserver()

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
        let config = configManager.config ?? .defaultConfig
        logService.configure(logDirectory: config.globalOptions.logDirectory)
        notificationService.configure(enabled: config.globalOptions.showNotifications)
        slackNotifier.configure(slackConfig: config.slack)
        bridgeService.configure(bridgeUrl: config.bridge?.url)
        if let cliPath = config.globalOptions.claudeCLIPath {
            claudeAutomator.cliPath = cliPath
        }
        schedulerEngine.restart()
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let config = configManager.config
        let schedules = config?.schedules ?? []

        // Update menu bar icon based on Claude status
        if let button = statusItem.button {
            button.title = claudeAutomator.status == .notInstalled ? "⚠️" : "🐙"
        }

        // Header
        let version = config?.version ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        let headerItem = NSMenuItem(title: "OCTOPUS Scheduler v\(version)", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        // Connection status (live)
        let bridgeOK = bridgeService.status == .connected
        let bridgeText: String
        switch bridgeService.status {
        case .connected:    bridgeText = "🟢 Connected to Bridge"
        case .disconnected: bridgeText = "🔴 Bridge disconnected"
        case .notConfigured: bridgeText = "⚪ Bridge not configured"
        }
        let bridgeStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        bridgeStatusItem.attributedTitle = styledStatus(bridgeText, active: bridgeOK)
        bridgeStatusItem.isEnabled = false
        menu.addItem(bridgeStatusItem)

        // Claude status
        let claudeOK = claudeAutomator.status == .ready
        let claudeText: String
        switch claudeAutomator.status {
        case .ready:        claudeText = "🟢 Claude ready"
        case .notRunning:   claudeText = "🟡 Claude Desktop not running"
        case .notInstalled: claudeText = "❌ Claude not available"
        }
        let claudeStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        claudeStatusItem.attributedTitle = styledStatus(claudeText, active: claudeOK)
        claudeStatusItem.isEnabled = false
        menu.addItem(claudeStatusItem)

        menu.addItem(NSMenuItem.separator())

        // Workflows
        if schedules.isEmpty {
            let item = NSMenuItem(title: "No schedules configured", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let workflowHeader = NSMenuItem(title: "Workflows", action: nil, keyEquivalent: "")
            workflowHeader.isEnabled = false
            menu.addItem(workflowHeader)

            let promptsDir = config?.resolvedPromptsDirectory ?? ""

            for schedule in schedules {
                let icon = schedule.enabled ? "▶" : "⏸"
                let item = NSMenuItem(title: "\(icon) \(schedule.name)", action: nil, keyEquivalent: "")

                let sub = NSMenu()

                // Info: schedule timing
                let days = schedule.schedule.daysOfWeek?.joined(separator: ", ") ?? "daily"
                let timeItem = NSMenuItem(title: "Schedule: \(schedule.schedule.time) · \(days)", action: nil, keyEquivalent: "")
                timeItem.isEnabled = false
                sub.addItem(timeItem)

                // Info: next fire / status
                if schedule.enabled {
                    let nextStr = formatNextFire(schedule)
                    let nextItem = NSMenuItem(title: "Next: \(nextStr)", action: nil, keyEquivalent: "")
                    nextItem.isEnabled = false
                    sub.addItem(nextItem)
                } else {
                    let pausedItem = NSMenuItem(title: "Status: paused", action: nil, keyEquivalent: "")
                    pausedItem.isEnabled = false
                    sub.addItem(pausedItem)
                }

                // Info: last run
                if let lastRun = schedulerEngine.lastExecution[schedule.id] {
                    let fmt = RelativeDateTimeFormatter()
                    fmt.unitsStyle = .abbreviated
                    let ago = fmt.localizedString(for: lastRun, relativeTo: Date())
                    let lastItem = NSMenuItem(title: "Last run: \(ago)", action: nil, keyEquivalent: "")
                    lastItem.isEnabled = false
                    sub.addItem(lastItem)
                }

                // Info: prompt file
                let fileItem = NSMenuItem(title: "Prompt: \(schedule.promptFile)", action: nil, keyEquivalent: "")
                fileItem.isEnabled = false
                sub.addItem(fileItem)

                sub.addItem(NSMenuItem.separator())

                // Action: Run Now
                let runItem = NSMenuItem(title: "Run Now", action: #selector(runNow(_:)), keyEquivalent: "")
                runItem.target = self
                runItem.representedObject = schedule.id
                sub.addItem(runItem)

                // Action: Open Prompt
                let promptPath = (promptsDir as NSString).appendingPathComponent(schedule.promptFile)
                let openPromptItem = NSMenuItem(title: "Open Prompt...", action: #selector(openPromptFile(_:)), keyEquivalent: "")
                openPromptItem.target = self
                openPromptItem.representedObject = promptPath
                sub.addItem(openPromptItem)

                // Action: Edit Schedule
                let editItem = NSMenuItem(title: "Edit Schedule...", action: #selector(editSchedule(_:)), keyEquivalent: "")
                editItem.target = self
                editItem.representedObject = schedule.id
                sub.addItem(editItem)

                sub.addItem(NSMenuItem.separator())

                // Action: Pause / Resume
                let toggleTitle = schedule.enabled ? "Pause" : "Resume"
                let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleSchedule(_:)), keyEquivalent: "")
                toggleItem.target = self
                toggleItem.representedObject = schedule.id
                sub.addItem(toggleItem)

                item.submenu = sub
                menu.addItem(item)
            }
        }

        // New Workflow
        let newWorkflowItem = NSMenuItem(title: "+ New Workflow...", action: #selector(addNewWorkflow), keyEquivalent: "n")
        newWorkflowItem.target = self
        menu.addItem(newWorkflowItem)

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

    private func styledStatus(_ text: String, active: Bool) -> NSAttributedString {
        let color: NSColor = active ? .white : .disabledControlTextColor
        return NSAttributedString(string: text, attributes: [.foregroundColor: color])
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

    @objc private func openPromptFile(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(url)
        } else {
            let alert = NSAlert()
            alert.messageText = "Prompt file not found"
            alert.informativeText = path
            alert.runModal()
        }
    }

    @objc private func addNewWorkflow() {
        guard var config = configManager.config else { return }
        let newId = UUID().uuidString.lowercased().prefix(8).description
        let newSchedule = ScheduleConfig(
            id: newId,
            name: "New Workflow",
            enabled: false,
            promptFile: "new-workflow.md",
            schedule: ScheduleTiming(type: "daily", time: "09:00", daysOfWeek: nil),
            options: ScheduleOptions()
        )
        config.schedules.append(newSchedule)
        configManager.config = config
        configManager.save()
        openEditorWindow(scheduleId: newId, title: "New Workflow", isNew: true)
    }

    @objc private func editSchedule(_ sender: NSMenuItem) {
        guard let scheduleId = sender.representedObject as? String else { return }
        let name = configManager.config?.schedules.first(where: { $0.id == scheduleId })?.name ?? "Schedule"
        openEditorWindow(scheduleId: scheduleId, title: "Edit: \(name)", isNew: false)
    }

    private func openEditorWindow(scheduleId: String, title: String, isNew: Bool) {
        let editorView = ScheduleEditorView(
            scheduleId: scheduleId,
            isNew: isNew,
            configManager: configManager,
            slackNotifier: slackNotifier,
            onSave: { [weak self] in
                self?.editorWindow?.close()
                self?.schedulerEngine.restart()
                self?.rebuildMenu()
            }
        )
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = NSHostingView(rootView: editorView)
        window.center()
        window.isReleasedWhenClosed = false
        editorWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

        // Show activity in menu bar immediately
        if let button = statusItem.button {
            button.title = "⏳"
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.schedulerEngine.executeNow(scheduleId: scheduleId)
            DispatchQueue.main.async {
                self?.rebuildMenu()
            }
        }
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let settingsView = SettingsView(
            configManager: configManager,
            schedulerEngine: schedulerEngine,
            onSave: { [weak self] in
                self?.settingsWindow?.close()
            }
        )
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "OctopusScheduler Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
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

    private func showCLISetupWizard() {
        let alert = NSAlert()
        alert.icon = makeAppIcon()
        alert.messageText = "Claude CLI Not Found"
        alert.informativeText = """
            OctopusScheduler works best with Claude Code CLI for reliable prompt delivery.

            Install it with:
            npm install -g @anthropic-ai/claude-code

            Without it, the app will fall back to AppleScript automation \
            (less reliable, requires Accessibility permission).
            """
        alert.addButton(withTitle: "Install Now")
        alert.addButton(withTitle: "Skip")

        if alert.runModal() == .alertFirstButtonReturn {
            let script = """
                tell application "Terminal"
                    activate
                    do script "npm install -g @anthropic-ai/claude-code"
                end tell
                """
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
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
