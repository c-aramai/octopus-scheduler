import SwiftUI

/// A SwiftUI view for potential future use as a popover-based menu bar interface.
/// Currently, the menu bar is implemented via NSMenu in AppDelegate.
struct MenuBarView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var schedulerEngine: SchedulerEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OctopusScheduler")
                .font(.headline)

            Divider()

            if let config = configManager.config {
                ForEach(config.schedules) { schedule in
                    HStack {
                        Image(systemName: schedule.enabled ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(schedule.enabled ? .green : .secondary)
                        Text(schedule.name)
                        Spacer()
                        Text(schedule.schedule.time)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No config loaded")
                    .foregroundColor(.secondary)
            }

            Divider()

            Button("Reload Config") {
                configManager.load()
                schedulerEngine.restart()
            }
        }
        .padding()
        .frame(width: 280)
    }
}
