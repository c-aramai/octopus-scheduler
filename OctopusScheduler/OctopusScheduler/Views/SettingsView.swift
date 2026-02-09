import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case schedules = "Schedules"
    case notifications = "Notifications"
    case help = "Help"
    case about = "About"
}

struct SettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var schedulerEngine: SchedulerEngine
    @ObservedObject var notificationService: NotificationService
    var onSave: (() -> Void)?
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(configManager: configManager, schedulerEngine: schedulerEngine, onSave: onSave)
                case .schedules:
                    SchedulesSettingsView(configManager: configManager, schedulerEngine: schedulerEngine)
                case .notifications:
                    NotificationsSettingsView(configManager: configManager, schedulerEngine: schedulerEngine, notificationService: notificationService, onSave: onSave)
                case .help:
                    HelpView()
                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 540, height: 440)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var schedulerEngine: SchedulerEngine
    var onSave: (() -> Void)?

    var body: some View {
        Form {
            if var config = configManager.config {
                TextField("Peer Name:", text: Binding(
                    get: { config.peerId ?? Host.current().localizedName ?? "unknown" },
                    set: { newValue in
                        config.peerId = newValue
                        configManager.config = config
                    }
                ))

                TextField("Domain:", text: Binding(
                    get: { config.domain ?? "aramai.io" },
                    set: { newValue in
                        config.domain = newValue
                        configManager.config = config
                    }
                ))

                TextField("Bridge URL:", text: Binding(
                    get: { config.bridge?.url ?? "https://octopus-bridge.vercel.app" },
                    set: { newValue in
                        if config.bridge == nil { config.bridge = BridgeConfig() }
                        config.bridge?.url = newValue
                        configManager.config = config
                    }
                ))

                TextField("Prompts Directory:", text: Binding(
                    get: { config.promptsDirectory },
                    set: { newValue in
                        config.promptsDirectory = newValue
                        configManager.config = config
                    }
                ))

                Toggle("Launch at Login", isOn: Binding(
                    get: { config.globalOptions.launchAtLogin },
                    set: { newValue in
                        config.globalOptions.launchAtLogin = newValue
                        configManager.config = config
                    }
                ))

                Divider()

                Text("HTTP Server")
                    .font(.headline)

                Toggle("Enable HTTP Server", isOn: Binding(
                    get: { config.http?.enabled ?? false },
                    set: { newValue in
                        if config.http == nil { config.http = HTTPConfig() }
                        config.http?.enabled = newValue
                        configManager.config = config
                    }
                ))

                TextField("Port:", text: Binding(
                    get: { String(config.http?.port ?? 19840) },
                    set: { newValue in
                        if config.http == nil { config.http = HTTPConfig() }
                        config.http?.port = Int(newValue) ?? 19840
                        configManager.config = config
                    }
                ))

                TextField("Secret:", text: Binding(
                    get: { config.http?.secret ?? "" },
                    set: { newValue in
                        if config.http == nil { config.http = HTTPConfig() }
                        config.http?.secret = newValue
                        configManager.config = config
                    }
                ))

                HStack {
                    Spacer()
                    Button("Save") {
                        configManager.save()
                        schedulerEngine.restart()
                        onSave?()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                Text("No configuration loaded.")
                    .foregroundColor(.secondary)
                Button("Reload Config") {
                    configManager.load()
                }
            }
        }
        .padding()
    }
}

// MARK: - Schedules

struct SchedulesSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var schedulerEngine: SchedulerEngine

    var body: some View {
        VStack(alignment: .leading) {
            if let config = configManager.config {
                List {
                    ForEach(config.schedules) { schedule in
                        HStack {
                            Image(systemName: schedule.enabled ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(schedule.enabled ? .green : .secondary)
                                .onTapGesture {
                                    configManager.toggleSchedule(id: schedule.id)
                                    schedulerEngine.restart()
                                }

                            VStack(alignment: .leading) {
                                Text(schedule.name).font(.headline)
                                HStack {
                                    Text("\(schedule.schedule.time) - \(schedule.promptFile)")
                                    if schedule.enabled, let next = schedule.nextFireDate() {
                                        Text("· next: \(nextFireLabel(next))")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Run") {
                                schedulerEngine.executeNow(scheduleId: schedule.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else {
                Text("No configuration loaded.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }

    private func nextFireLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        if calendar.isDateInToday(date) {
            return "today \(fmt.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "tomorrow \(fmt.string(from: date))"
        } else {
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "EEEE h:mm a"
            return dayFmt.string(from: date)
        }
    }
}

// MARK: - Notifications

struct NotificationsSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var schedulerEngine: SchedulerEngine
    @ObservedObject var notificationService: NotificationService
    var onSave: (() -> Void)?

    private var notificationStatusText: (String, Color)? {
        switch notificationService.authorizationStatus {
        case .denied:
            return ("Notifications blocked — enable in System Settings > Notifications", .red)
        case .notDetermined:
            return ("Notification permission not yet requested", .secondary)
        case .provisional, .authorized, .ephemeral:
            return nil
        @unknown default:
            return nil
        }
    }

    private func webhookWarning(_ url: String?) -> String? {
        guard let url = url, !url.isEmpty else { return nil }
        if url.hasPrefix("https://hooks.slack.com/services/") { return nil }
        if url.hasPrefix("https://hooks.slack.com/workflows/") { return nil }
        return "Expected format: https://hooks.slack.com/services/T.../B.../..."
    }

    var body: some View {
        Form {
            if var config = configManager.config {
                TextField("Slack Webhook URL:", text: Binding(
                    get: { config.slack?.webhookUrl ?? "" },
                    set: { newValue in
                        if config.slack == nil { config.slack = SlackConfig() }
                        config.slack?.webhookUrl = newValue.isEmpty ? nil : newValue
                        configManager.config = config
                    }
                ))

                if let warning = webhookWarning(config.slack?.webhookUrl) {
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                TextField("Default Slack Channel:", text: Binding(
                    get: { config.slack?.defaultChannel ?? "" },
                    set: { newValue in
                        if config.slack == nil { config.slack = SlackConfig() }
                        config.slack?.defaultChannel = newValue.isEmpty ? nil : newValue
                        configManager.config = config
                    }
                ))

                Toggle("Show Notifications", isOn: Binding(
                    get: { config.globalOptions.showNotifications },
                    set: { newValue in
                        config.globalOptions.showNotifications = newValue
                        configManager.config = config
                    }
                ))

                if let (text, color) = notificationStatusText {
                    Text(text)
                        .font(.caption)
                        .foregroundColor(color)
                }

                Toggle("Notify on workflow complete", isOn: Binding(
                    get: { config.slack?.notifyOnComplete ?? true },
                    set: { newValue in
                        if config.slack == nil { config.slack = SlackConfig() }
                        config.slack?.notifyOnComplete = newValue
                        configManager.config = config
                    }
                ))

                Toggle("Notify on workflow failure", isOn: Binding(
                    get: { config.slack?.notifyOnFailure ?? true },
                    set: { newValue in
                        if config.slack == nil { config.slack = SlackConfig() }
                        config.slack?.notifyOnFailure = newValue
                        configManager.config = config
                    }
                ))

                HStack {
                    Spacer()
                    Button("Save") {
                        configManager.save()
                        onSave?()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                Text("No configuration loaded.")
                    .foregroundColor(.secondary)
                Button("Reload Config") {
                    configManager.load()
                }
            }
        }
        .padding()
    }
}

// MARK: - Schedule Editor

struct ScheduleEditorView: View {
    let scheduleId: String
    let isNew: Bool
    @ObservedObject var configManager: ConfigManager
    var slackNotifier: SlackNotifier?
    var onSave: (() -> Void)?

    @State private var name: String = ""
    @State private var time: String = ""
    @State private var promptFile: String = ""
    @State private var enabled: Bool = true
    @State private var mon = false
    @State private var tue = false
    @State private var wed = false
    @State private var thu = false
    @State private var fri = false
    @State private var sat = false
    @State private var sun = false
    @State private var newConversation: Bool = true
    @State private var slackChannel: String = ""
    @State private var showDeleteConfirm = false
    @State private var showSavedPill = false
    @State private var saveDebounce: Timer?
    @State private var slackTestResult: String?
    @State private var slackTestOK = false
    @State private var slackTesting = false

    init(scheduleId: String, isNew: Bool = false, configManager: ConfigManager, slackNotifier: SlackNotifier? = nil, onSave: (() -> Void)? = nil) {
        self.scheduleId = scheduleId
        self.isNew = isNew
        self.configManager = configManager
        self.slackNotifier = slackNotifier
        self.onSave = onSave
    }

    private var schedule: ScheduleConfig? {
        configManager.config?.schedules.first(where: { $0.id == scheduleId })
    }

    private var promptsDir: String {
        configManager.config?.resolvedPromptsDirectory ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Name:", text: $name)
                TextField("Time (HH:mm):", text: $time)
                HStack(spacing: 6) {
                    TextField("Prompt file:", text: $promptFile)
                        .lineLimit(1)
                        .frame(maxWidth: 240)
                    Button(action: openPrompt) {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Open prompt file in editor")
                }
                Toggle("Enabled", isOn: $enabled)

                Divider()

                Text("Days of week").font(.headline)
                HStack(spacing: 12) {
                    DayToggle(label: "Mon", isOn: $mon)
                    DayToggle(label: "Tue", isOn: $tue)
                    DayToggle(label: "Wed", isOn: $wed)
                    DayToggle(label: "Thu", isOn: $thu)
                    DayToggle(label: "Fri", isOn: $fri)
                    DayToggle(label: "Sat", isOn: $sat)
                    DayToggle(label: "Sun", isOn: $sun)
                }
                Text("Leave all off for daily")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Toggle("New conversation each run", isOn: $newConversation)

                HStack(spacing: 6) {
                    TextField("Slack channel:", text: $slackChannel, prompt: Text("none"))
                        .frame(maxWidth: 200)
                    Button(slackTesting ? "Testing..." : "Test") {
                        testSlackChannel()
                    }
                    .disabled(slackTesting)
                    .controlSize(.small)

                    if let result = slackTestResult {
                        Text(slackTestOK ? "Sent" : result)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(slackTestOK ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .onChange(of: name) { _ in debounceSave() }
            .onChange(of: time) { _ in debounceSave() }
            .onChange(of: promptFile) { _ in debounceSave() }
            .onChange(of: enabled) { _ in debounceSave() }
            .onChange(of: newConversation) { _ in debounceSave() }
            .onChange(of: slackChannel) { _ in debounceSave() }
            .onChange(of: mon) { _ in debounceSave() }
            .onChange(of: tue) { _ in debounceSave() }
            .onChange(of: wed) { _ in debounceSave() }
            .onChange(of: thu) { _ in debounceSave() }
            .onChange(of: fri) { _ in debounceSave() }
            .onChange(of: sat) { _ in debounceSave() }
            .onChange(of: sun) { _ in debounceSave() }

            Divider()

            HStack(spacing: 12) {
                if !isNew {
                    Button(role: .destructive, action: { showDeleteConfirm = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                }

                Button(action: openConfigJSON) {
                    Label("Edit JSON", systemImage: "curlybraces")
                }
                .buttonStyle(.borderless)

                Spacer()

                if showSavedPill {
                    Text("Saved")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.opacity)
                }

                Button("Cancel") {
                    if isNew { removeNewSchedule() }
                    onSave?()
                }
                .keyboardShortcut(.cancelAction)
                Button("Done") {
                    saveSchedule()
                    onSave?()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .padding(.top)
        .frame(width: 400)
        .onAppear { loadFromSchedule() }
        .alert("Delete Workflow?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSchedule()
                onSave?()
            }
        } message: {
            Text("Are you sure you want to delete \"\(name)\"? This cannot be undone.")
        }
    }

    private func debounceSave() {
        saveDebounce?.invalidate()
        saveDebounce = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
            saveSchedule()
            withAnimation {
                showSavedPill = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation {
                    showSavedPill = false
                }
            }
        }
    }

    private func testSlackChannel() {
        guard let notifier = slackNotifier else {
            slackTestResult = "No webhook"
            slackTestOK = false
            return
        }
        slackTesting = true
        slackTestResult = nil
        Task {
            let channel = slackChannel.isEmpty ? nil : slackChannel
            let error = await notifier.testChannel(channel)
            await MainActor.run {
                slackTesting = false
                slackTestOK = error == nil
                slackTestResult = error ?? "Sent"
                // Clear result after a few seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    slackTestResult = nil
                }
            }
        }
    }

    private func openPrompt() {
        let path = (promptsDir as NSString).appendingPathComponent(promptFile)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else {
            // Open the prompts directory so they can create the file
            let dir = promptsDir
            if FileManager.default.fileExists(atPath: dir) {
                NSWorkspace.shared.open(URL(fileURLWithPath: dir, isDirectory: true))
            }
        }
    }

    private func openConfigJSON() {
        let path = ("~/.octopus-scheduler/config.json" as NSString).expandingTildeInPath
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func loadFromSchedule() {
        guard let s = schedule else { return }
        name = s.name
        time = s.schedule.time
        promptFile = s.promptFile
        enabled = s.enabled
        newConversation = s.options.newConversation ?? true
        slackChannel = s.options.slackChannel ?? ""
        let days = Set(s.schedule.daysOfWeek ?? [])
        mon = days.contains("mon")
        tue = days.contains("tue")
        wed = days.contains("wed")
        thu = days.contains("thu")
        fri = days.contains("fri")
        sat = days.contains("sat")
        sun = days.contains("sun")
    }

    private func removeNewSchedule() {
        removeFromConfig()
    }

    private func deleteSchedule() {
        removeFromConfig()
    }

    private func removeFromConfig() {
        guard var config = configManager.config else { return }
        config.schedules.removeAll(where: { $0.id == scheduleId })
        configManager.config = config
        configManager.save()
    }

    private func saveSchedule() {
        guard var config = configManager.config,
              let idx = config.schedules.firstIndex(where: { $0.id == scheduleId }) else { return }

        var days: [String] = []
        if mon { days.append("mon") }
        if tue { days.append("tue") }
        if wed { days.append("wed") }
        if thu { days.append("thu") }
        if fri { days.append("fri") }
        if sat { days.append("sat") }
        if sun { days.append("sun") }

        config.schedules[idx].name = name
        config.schedules[idx].enabled = enabled
        config.schedules[idx].promptFile = promptFile
        config.schedules[idx].schedule.time = time
        config.schedules[idx].schedule.daysOfWeek = days.isEmpty ? nil : days
        config.schedules[idx].options.newConversation = newConversation
        config.schedules[idx].options.slackChannel = slackChannel.isEmpty ? nil : slackChannel

        configManager.config = config
        configManager.save()
    }
}

private struct DayToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(label)
                .font(.caption)
                .frame(width: 32, height: 24)
                .background(isOn ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundColor(isOn ? .white : .primary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Help

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("How It Works").font(.headline)
                    Text("Schedules fire at configured times. Each schedule loads a prompt template, renders variables, and sends it via Claude Code CLI (primary) or AppleScript automation (fallback).")
                }

                Group {
                    Text("Setup").font(.headline)
                    Text("1. Install Claude Code CLI:")
                    Text("   npm install -g @anthropic-ai/claude-code")
                        .font(.system(.body, design: .monospaced))
                    Text("2. For AppleScript fallback, grant Accessibility permission to OctopusScheduler in System Settings > Privacy & Security > Accessibility.")
                }

                Group {
                    Text("Config Reference").font(.headline)
                    Text("""
                        Edit ~/.octopus-scheduler/config.json:
                        • schedules — array of schedule objects (name, time, promptFile, enabled)
                        • globalOptions — launchAtLogin, showNotifications, claudeCLIPath, logDirectory
                        • bridge — url, reconnectInterval
                        • slack — webhookUrl, defaultChannel, notifyOnComplete/Failure
                        • http — enabled, port, secret
                        """)
                }

                Group {
                    Text("Prompt Templates").font(.headline)
                    Text("Place .md files in your prompts directory (default: ~/ARAMAI/prompts/scheduled). Use {{CURRENT_DATE}} for date substitution.")
                }

                Group {
                    Text("File Locations").font(.headline)
                    Text("""
                        • ~/.octopus-scheduler/config.json — main configuration
                        • ~/.octopus-scheduler/state.json — last-fired timestamps
                        • ~/.octopus-scheduler/logs/ — daily log files
                        """)
                }

                Group {
                    Text("Troubleshooting").font(.headline)
                    Text("""
                        CLI not found — Install with npm or set claudeCLIPath in globalOptions to the full path.
                        AppleScript fails — Ensure Claude Desktop is installed and Accessibility permission is granted.
                        Schedule didn't fire — Check that the schedule is enabled, the prompt file exists, and view logs for errors.
                        """)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("ARAMAI")
                .font(.title)
                .fontWeight(.semibold)
            Text("OCTOPUS Scheduler")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0")")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("Part of the Semantic Intelligence Architecture")
                .font(.callout)
                .foregroundColor(.secondary)
            Text("© 2026 Hexagon Holdings LLC (ADGM)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
