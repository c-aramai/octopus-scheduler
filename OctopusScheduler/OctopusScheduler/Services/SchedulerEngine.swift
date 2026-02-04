import Foundation

class SchedulerEngine: ObservableObject {
    @Published var lastExecution: [String: Date] = [:]

    private var configManager: ConfigManager?
    private var promptLoader: PromptLoader?
    private var claudeAutomator: ClaudeAutomator?
    private var notificationService: NotificationService?
    private var logService: LogService?
    private var timers: [String: Timer] = [:]

    func configure(
        configManager: ConfigManager,
        promptLoader: PromptLoader,
        claudeAutomator: ClaudeAutomator,
        notificationService: NotificationService,
        logService: LogService
    ) {
        self.configManager = configManager
        self.promptLoader = promptLoader
        self.claudeAutomator = claudeAutomator
        self.notificationService = notificationService
        self.logService = logService
    }

    func start() {
        guard let config = configManager?.config else {
            logService?.log("No config loaded, nothing to schedule")
            return
        }

        for schedule in config.schedules where schedule.enabled {
            scheduleNext(schedule, promptsDir: config.resolvedPromptsDirectory)
        }
        logService?.log("Scheduler started with \(timers.count) active timer(s)")
    }

    func stop() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        logService?.log("Scheduler stopped all timers")
    }

    func restart() {
        stop()
        start()
    }

    func executeNow(scheduleId: String) {
        guard let config = configManager?.config,
              let schedule = config.schedules.first(where: { $0.id == scheduleId }) else {
            logService?.error("Schedule '\(scheduleId)' not found")
            return
        }
        execute(schedule, promptsDir: config.resolvedPromptsDirectory)
    }

    // MARK: - Private

    private func scheduleNext(_ schedule: ScheduleConfig, promptsDir: String) {
        guard let nextFire = schedule.nextFireDate() else {
            logService?.error("Could not compute next fire date for '\(schedule.name)'")
            return
        }

        let interval = nextFire.timeIntervalSinceNow
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        logService?.log("'\(schedule.name)' next fire: \(formatter.string(from: nextFire)) (in \(Int(interval))s)")

        let timer = Timer(fire: nextFire, interval: 0, repeats: false) { [weak self] _ in
            self?.execute(schedule, promptsDir: promptsDir)
            self?.scheduleNext(schedule, promptsDir: promptsDir)
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[schedule.id] = timer
    }

    private func execute(_ schedule: ScheduleConfig, promptsDir: String) {
        logService?.log("Executing '\(schedule.name)'...")
        notificationService?.notify(
            title: "OctopusScheduler",
            body: "Running: \(schedule.name)"
        )

        let filePath = (promptsDir as NSString).appendingPathComponent(schedule.promptFile)
        guard let template = promptLoader?.load(from: filePath) else {
            logService?.error("Failed to load prompt from \(filePath)")
            notificationService?.notify(
                title: "OctopusScheduler",
                body: "\(schedule.name) failed: could not load prompt file"
            )
            return
        }

        let renderedPrompt = template.rendered()
        let newConversation = schedule.options.newConversation ?? true

        let success = claudeAutomator?.sendPromptToClaude(renderedPrompt, newConversation: newConversation) ?? false
        if success {
            logService?.log("'\(schedule.name)' sent successfully")
            notificationService?.notify(
                title: "OctopusScheduler",
                body: "\(schedule.name) sent to Claude"
            )
            DispatchQueue.main.async {
                self.lastExecution[schedule.id] = Date()
            }
        } else {
            logService?.error("'\(schedule.name)' failed to send")
            notificationService?.notify(
                title: "OctopusScheduler",
                body: "\(schedule.name) failed to send"
            )
        }
    }
}
