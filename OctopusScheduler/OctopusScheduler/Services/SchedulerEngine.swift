import Foundation
import AppKit

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

    // MARK: - State Persistence

    private static let statePath = ("~/.octopus-scheduler/state.json" as NSString).expandingTildeInPath

    private struct PersistedState: Codable {
        var lastFiredAt: [String: Date]
    }

    private func loadState() {
        guard let data = FileManager.default.contents(atPath: Self.statePath) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(PersistedState.self, from: data)
            lastExecution = state.lastFiredAt
            logService?.log("Restored state for \(state.lastFiredAt.count) schedule(s)")
        } catch {
            logService?.error("Failed to load state: \(error.localizedDescription)")
        }
    }

    private func saveState() {
        let state = PersistedState(lastFiredAt: lastExecution)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            let dir = (Self.statePath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try data.write(to: URL(fileURLWithPath: Self.statePath))
        } catch {
            logService?.error("Failed to save state: \(error.localizedDescription)")
        }
    }

    // MARK: - Execution Locking

    private var runningSchedules: Set<String> = []

    private var allowConcurrentExecutions: Bool {
        configManager?.config?.globalOptions.allowConcurrentExecutions ?? false
    }

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
        loadState()
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
        executeWithRetry(schedule, promptsDir: config.resolvedPromptsDirectory)
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
            self?.executeWithRetry(schedule, promptsDir: promptsDir)
            self?.scheduleNext(schedule, promptsDir: promptsDir)
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[schedule.id] = timer
    }

    private func executeWithRetry(_ schedule: ScheduleConfig, promptsDir: String, delayed: Bool = false) {
        let prefix = delayed ? "[DELAYED] " : ""

        // Health check (non-retriable)
        if let automator = claudeAutomator, automator.status == .notInstalled {
            let errorMsg = "Claude Desktop not installed"
            logService?.error("\(prefix)'\(schedule.name)' — \(errorMsg)")
            notificationService?.notify(title: "OctopusScheduler", body: "\(schedule.name): \(errorMsg)")
            appendHistory(ExecutionRecord(scheduleId: schedule.id, scheduleName: schedule.name, timestamp: Date(), success: false, error: errorMsg))
            return
        }

        // Locking check
        if runningSchedules.contains(schedule.id) {
            logService?.log("'\(schedule.name)' skipped — already running")
            return
        }
        if !allowConcurrentExecutions && !runningSchedules.isEmpty {
            logService?.log("'\(schedule.name)' skipped — another schedule is running")
            return
        }
        runningSchedules.insert(schedule.id)
        defer { runningSchedules.remove(schedule.id) }

        logService?.log("\(prefix)Executing '\(schedule.name)'...")
        notificationService?.notify(title: "OctopusScheduler", body: "\(prefix)Running: \(schedule.name)")

        // Load prompt (non-retriable)
        let filePath = (promptsDir as NSString).appendingPathComponent(schedule.promptFile)
        guard let template = promptLoader?.load(from: filePath) else {
            let errorMsg = "Could not load prompt file"
            logService?.error("Failed to load prompt from \(filePath)")
            notificationService?.notify(title: "OctopusScheduler", body: "\(schedule.name) failed: could not load prompt file")
            slackNotifier?.notify(event: SchedulerEvent(type: "prompt.failed", scheduleId: schedule.id, scheduleName: schedule.name, error: errorMsg, channel: schedule.options.slackChannel))
            appendHistory(ExecutionRecord(scheduleId: schedule.id, scheduleName: schedule.name, timestamp: Date(), success: false, error: errorMsg))
            return
        }

        let renderedPrompt = template.rendered()
        let newConversation = schedule.options.newConversation ?? true
        let channel = schedule.options.slackChannel

        slackNotifier?.notify(event: SchedulerEvent(type: "prompt.fired", scheduleId: schedule.id, scheduleName: schedule.name, channel: channel))

        // Retry loop: initial attempt + 3 retries
        let backoff: [TimeInterval] = [5, 15, 45]
        let maxAttempts = 1 + backoff.count

        for attempt in 1...maxAttempts {
            let success = claudeAutomator?.sendPrompt(renderedPrompt, newConversation: newConversation) ?? false
            if success {
                logService?.log("\(prefix)'\(schedule.name)' sent successfully")
                notificationService?.notify(title: "OctopusScheduler", body: "\(prefix)\(schedule.name) sent to Claude")
                slackNotifier?.notify(event: SchedulerEvent(type: "prompt.succeeded", scheduleId: schedule.id, scheduleName: schedule.name, channel: channel))
                appendHistory(ExecutionRecord(scheduleId: schedule.id, scheduleName: schedule.name, timestamp: Date(), success: true, error: nil))
                DispatchQueue.main.async {
                    self.lastExecution[schedule.id] = Date()
                    self.saveState()
                }
                return
            }

            if attempt < maxAttempts {
                let delay = backoff[attempt - 1]
                logService?.log("'\(schedule.name)' retry \(attempt)/\(backoff.count) after \(Int(delay))s")
                Thread.sleep(forTimeInterval: delay)
            }
        }

        // All attempts exhausted
        let errorMsg = "Failed after \(maxAttempts) attempts"
        logService?.error("\(prefix)'\(schedule.name)' \(errorMsg)")
        notificationService?.notify(title: "OctopusScheduler", body: "\(prefix)\(schedule.name) failed to send")
        slackNotifier?.notify(event: SchedulerEvent(type: "prompt.failed", scheduleId: schedule.id, scheduleName: schedule.name, error: errorMsg, channel: channel))
        appendHistory(ExecutionRecord(scheduleId: schedule.id, scheduleName: schedule.name, timestamp: Date(), success: false, error: errorMsg))
    }

    private func appendHistory(_ record: ExecutionRecord) {
        executionHistory.append(record)
        if executionHistory.count > maxHistory {
            executionHistory.removeFirst(executionHistory.count - maxHistory)
        }
    }

    // MARK: - Sleep/Wake Recovery

    func startWakeObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.logService?.log("System woke from sleep — checking for missed fires")
            self?.checkMissedFires()
        }
    }

    private func checkMissedFires() {
        guard let config = configManager?.config else { return }
        let now = Date()
        for schedule in config.schedules where schedule.enabled {
            guard let lastFired = lastExecution[schedule.id] else { continue }
            guard let shouldHaveFired = schedule.nextFireDate(after: lastFired) else { continue }
            if shouldHaveFired < now {
                logService?.log("[DELAYED] '\(schedule.name)' missed fire at \(shouldHaveFired) — executing now")
                executeWithRetry(schedule, promptsDir: config.resolvedPromptsDirectory, delayed: true)
            }
        }
        restart()
    }
}
