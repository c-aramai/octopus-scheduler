import SwiftUI

struct SettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var schedulerEngine: SchedulerEngine

    var body: some View {
        TabView {
            GeneralSettingsView(configManager: configManager, schedulerEngine: schedulerEngine)
                .tabItem { Label("General", systemImage: "gear") }

            SchedulesSettingsView(configManager: configManager, schedulerEngine: schedulerEngine)
                .tabItem { Label("Schedules", systemImage: "clock") }

            NotificationsSettingsView(configManager: configManager, schedulerEngine: schedulerEngine)
                .tabItem { Label("Notifications", systemImage: "bell") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 400)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var schedulerEngine: SchedulerEngine

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

                HStack {
                    Spacer()
                    Button("Save") {
                        configManager.save()
                        schedulerEngine.restart()
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
