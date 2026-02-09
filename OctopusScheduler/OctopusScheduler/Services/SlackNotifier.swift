import Foundation

struct SchedulerEvent {
    let type: String          // prompt.fired, prompt.succeeded, prompt.failed
    let scheduleId: String
    let scheduleName: String
    let timestamp: Date
    let error: String?
    let channel: String?

    init(type: String, scheduleId: String, scheduleName: String, error: String? = nil, channel: String? = nil) {
        self.type = type
        self.scheduleId = scheduleId
        self.scheduleName = scheduleName
        self.timestamp = Date()
        self.error = error
        self.channel = channel
    }
}

class SlackNotifier {
    private var webhookUrl: String?
    private var defaultChannel: String?
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
        self.defaultChannel = config.defaultChannel
        self.notifyOnComplete = config.notifyOnComplete ?? true
        self.notifyOnFailure = config.notifyOnFailure ?? true
    }

    func notify(event: SchedulerEvent) {
        guard let urlString = webhookUrl, let url = URL(string: urlString) else { return }

        // Respect notification preferences
        if event.type == "prompt.succeeded" && !notifyOnComplete { return }
        if event.type == "prompt.failed" && !notifyOnFailure { return }

        let emoji: String
        let verb: String
        switch event.type {
        case "prompt.fired":     emoji = "🚀"; verb = "Started"
        case "prompt.succeeded": emoji = "✅"; verb = "Completed"
        case "prompt.failed":    emoji = "❌"; verb = "Failed"
        default:                 emoji = "📋"; verb = event.type
        }

        var text = "\(emoji) *\(verb):* \(event.scheduleName)"
        if let error = event.error {
            text += "\n> \(error)"
        }

        var payload: [String: Any] = ["text": text]
        if var channel = event.channel ?? defaultChannel, !channel.isEmpty {
            if channel.hasPrefix("#") { channel = String(channel.dropFirst()) }
            payload["channel"] = channel
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

    /// Sends a test message to validate webhook + channel. Returns nil on success, or error string.
    func testChannel(_ channel: String?) async -> String? {
        guard let urlString = webhookUrl, let url = URL(string: urlString) else {
            return "No Slack webhook configured"
        }

        var payload: [String: Any] = ["text": "🧪 OctopusScheduler test message"]
        if var ch = channel ?? defaultChannel, !ch.isEmpty {
            // Strip leading # — Slack expects bare channel name
            if ch.hasPrefix("#") { ch = String(ch.dropFirst()) }
            payload["channel"] = ch
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return "Failed to build request"
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                let responseBody = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return Self.friendlySlackError(status: httpResponse.statusCode, body: responseBody)
            }
            return nil
        } catch {
            return "Connection failed"
        }
    }

    private static func friendlySlackError(status: Int, body: String) -> String {
        switch status {
        case 404:
            return "Webhook URL not found — check Settings"
        case 403:
            return "Webhook access denied"
        case 410:
            return "Webhook has been revoked"
        default:
            break
        }
        switch body {
        case "channel_not_found":
            return "Channel not found"
        case "invalid_payload":
            return "Invalid message format"
        case "no_text":
            return "Empty message"
        case "channel_is_archived":
            return "Channel is archived"
        default:
            return body.isEmpty ? "Error \(status)" : body
        }
    }
}
