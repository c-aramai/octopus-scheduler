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

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 360)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var schedulerEngine: SchedulerEngine

    var body: some View {
        Form {
            if var config = configManager.config {
                TextField("Prompts Directory:", text: Binding(
                    get: { config.promptsDirectory },
                    set: { newValue in
                        config.promptsDirectory = newValue
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
                                Text("\(schedule.schedule.time) - \(schedule.promptFile)")
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
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("OctopusScheduler")
                .font(.title)
            Text("Automated Claude Desktop Scheduling")
                .foregroundColor(.secondary)
            Text("Version 1.0")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("Orchestrated Claude Task Operations\nfor Proactive Unified Scheduling")
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
