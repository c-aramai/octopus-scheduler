import Foundation

struct SchedulerEvent {
    let type: String          // prompt.fired, prompt.succeeded, prompt.failed
    let scheduleId: String
    let scheduleName: String
    let timestamp: Date
    let error: String?

    init(type: String, scheduleId: String, scheduleName: String, error: String? = nil) {
        self.type = type
        self.scheduleId = scheduleId
        self.scheduleName = scheduleName
        self.timestamp = Date()
        self.error = error
    }
}

class SlackNotifier {
    private var webhookUrl: String?
    private var notifyOnComplete: Bool = true
    private var notifyOnFailure: Bool = true

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func configure(slackConfig: SlackConfig?) {
        guard let config = slackConfig,
              let url = config.webhookUrl, !url.isEmpty else {
            self.webhookUrl = nil
            return
        }
        self.webhookUrl = url
        self.notifyOnComplete = config.notifyOnComplete ?? true
        self.notifyOnFailure = config.notifyOnFailure ?? true
    }

    func notify(event: SchedulerEvent) {
        guard let urlString = webhookUrl, let url = URL(string: urlString) else { return }

        // Respect notification preferences
        if event.type == "prompt.succeeded" && !notifyOnComplete { return }
        if event.type == "prompt.failed" && !notifyOnFailure { return }

        var payload: [String: Any] = [
            "type": event.type,
            "scheduleId": event.scheduleId,
            "scheduleName": event.scheduleName,
            "timestamp": isoFormatter.string(from: event.timestamp)
        ]
        if let error = event.error {
            payload["error"] = error
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        // Fire-and-forget
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                    print("[SlackNotifier] Webhook returned \(httpResponse.statusCode) for \(event.type)")
                }
            } catch {
                print("[SlackNotifier] Failed to send \(event.type): \(error.localizedDescription)")
            }
        }
    }
}
