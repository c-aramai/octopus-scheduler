import Foundation

struct ExecutionRecord {
    let scheduleId: String
    let scheduleName: String
    let timestamp: Date
    let success: Bool
    let error: String?
}

class SchedulerEngine: ObservableObject {
    @Published var lastExecution: [String: Date] = [:]
    private(set) var executionHistory: [ExecutionRecord] = []
    private let maxHistory = 50

    private var configManager: ConfigManager?
    private var promptLoader: PromptLoader?
    private var claudeAutomator: ClaudeAutomator?
    private var notificationService: NotificationService?
    private var logService: LogService?
    private var slackNotifier: SlackNotifier?
    private var timers: [String: Timer] = [:]

    func configure(
        configManager: ConfigManager,
        promptLoader: PromptLoader,
        claudeAutomator: ClaudeAutomator,
        notificationService: NotificationService,
        logService: LogService,
        slackNotifier: SlackNotifier? = nil
    ) {
        self.configManager = configManager
        self.promptLoader = promptLoader
        self.claudeAutomator = claudeAutomator
        self.notificationService = notificationService
        self.logService = logService
        self.slackNotifier = slackNotifier
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
            let errorMsg = "Could not load prompt file"
            logService?.error("Failed to load prompt from \(filePath)")
            notificationService?.notify(
                title: "OctopusScheduler",
                body: "\(schedule.name) failed: could not load prompt file"
            )
            slackNotifier?.notify(event: SchedulerEvent(
                type: "prompt.failed",
                scheduleId: schedule.id,
                scheduleName: schedule.name,
                error: errorMsg
            ))
            appendHistory(ExecutionRecord(scheduleId: schedule.id, scheduleName: schedule.name, timestamp: Date(), success: false, error: errorMsg))
            return
        }

        let renderedPrompt = template.rendered()
        let newConversation = schedule.options.newConversation ?? true

        slackNotifier?.notify(event: SchedulerEvent(
            type: "prompt.fired",
            scheduleId: schedule.id,
            scheduleName: schedule.name
        ))

        let success = claudeAutomator?.sendPromptToClaude(renderedPrompt, newConversation: newConversation) ?? false
        if success {
            logService?.log("'\(schedule.name)' sent successfully")
            notificationService?.notify(
                title: "OctopusScheduler",
                body: "\(schedule.name) sent to Claude"
            )
            slackNotifier?.notify(event: SchedulerEvent(
                type: "prompt.succeeded",
                scheduleId: schedule.id,
                scheduleName: schedule.name
            ))
            appendHistory(ExecutionRecord(scheduleId: schedule.id, scheduleName: schedule.name, timestamp: Date(), success: true, error: nil))
            DispatchQueue.main.async {
                self.lastExecution[schedule.id] = Date()
            }
        } else {
            let errorMsg = "Failed to send prompt to Claude"
            logService?.error("'\(schedule.name)' failed to send")
            notificationService?.notify(
                title: "OctopusScheduler",
                body: "\(schedule.name) failed to send"
            )
            slackNotifier?.notify(event: SchedulerEvent(
                type: "prompt.failed",
                scheduleId: schedule.id,
                scheduleName: schedule.name,
                error: errorMsg
            ))
            appendHistory(ExecutionRecord(scheduleId: schedule.id, scheduleName: schedule.name, timestamp: Date(), success: false, error: errorMsg))
        }
    }

    private func appendHistory(_ record: ExecutionRecord) {
        executionHistory.append(record)
        if executionHistory.count > maxHistory {
            executionHistory.removeFirst(executionHistory.count - maxHistory)
        }
    }
}
