import CryptoKit
import Foundation
import Network

class SchedulerHTTPServer {
    private var listener: NWListener?
    private var secret: String = ""
    private weak var schedulerEngine: SchedulerEngine?
    private weak var configManager: ConfigManager?
    private weak var logService: LogService?
    private weak var slackNotifier: SlackNotifier?
    var bridgeForwardConfig: BridgeForwardConfig?
    private let startTime = Date()

    func start(config: HTTPConfig, schedulerEngine: SchedulerEngine, configManager: ConfigManager, logService: LogService?, slackNotifier: SlackNotifier? = nil, bridgeForwardConfig: BridgeForwardConfig? = nil) {
        self.secret = config.secret
        self.schedulerEngine = schedulerEngine
        self.configManager = configManager
        self.logService = logService
        self.slackNotifier = slackNotifier
        self.bridgeForwardConfig = bridgeForwardConfig

        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: UInt16(config.port)))
        } catch {
            logService?.error("HTTP server failed to create listener: \(error.localizedDescription)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.logService?.log("HTTP server listening on port \(config.port)")
            case .failed(let error):
                self?.logService?.error("HTTP server failed: \(error.localizedDescription)")
                self?.listener?.cancel()
            default:
                break
            }
        }

        listener?.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
        logService?.log("HTTP server stopped")
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        receiveData(on: connection, accumulated: Data())
    }

    private func receiveData(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else {
                connection.cancel()
                return
            }

            if let error = error {
                self.logService?.error("HTTP connection error: \(error.localizedDescription)")
                connection.cancel()
                return
            }

            var data = accumulated
            if let content = content {
                data.append(content)
            }

            // Check if we have a complete HTTP request (headers end with \r\n\r\n)
            if let headerEnd = self.findHeaderEnd(in: data) {
                let headerData = data[data.startIndex..<headerEnd]
                let headerString = String(data: headerData, encoding: .utf8) ?? ""
                let contentLength = self.parseContentLength(from: headerString)
                let bodyStart = headerEnd + 4 // skip \r\n\r\n
                let bodyReceived = data.count - bodyStart

                if bodyReceived >= contentLength {
                    // Full request received
                    self.processRequest(data: data, connection: connection)
                } else if isComplete {
                    // Connection closed before full body -- process what we have
                    self.processRequest(data: data, connection: connection)
                } else {
                    // Need more body data
                    self.receiveData(on: connection, accumulated: data)
                }
            } else if isComplete {
                // Connection closed, process whatever we got
                if !data.isEmpty {
                    self.processRequest(data: data, connection: connection)
                } else {
                    connection.cancel()
                }
            } else {
                // Need more header data
                self.receiveData(on: connection, accumulated: data)
            }
        }
    }

    private func findHeaderEnd(in data: Data) -> Int? {
        let separator: [UInt8] = [0x0D, 0x0A, 0x0D, 0x0A] // \r\n\r\n
        let bytes = Array(data)
        guard bytes.count >= 4 else { return nil }
        for i in 0...(bytes.count - 4) {
            if bytes[i] == separator[0] && bytes[i+1] == separator[1] &&
               bytes[i+2] == separator[2] && bytes[i+3] == separator[3] {
                return i
            }
        }
        return nil
    }

    private func parseContentLength(from headers: String) -> Int {
        for line in headers.components(separatedBy: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                return Int(value) ?? 0
            }
        }
        return 0
    }

    // MARK: - Request Processing

    private func processRequest(data: Data, connection: NWConnection) {
        guard let request = parseHTTPRequest(data: data) else {
            sendResponse(connection: connection, status: 400, body: ["error": "Bad request"])
            return
        }

        // Bridge events use HMAC auth, not Bearer token
        if request.method == "POST" && request.path == "/bridge/events" {
            handleBridgeEvent(request: request, connection: connection)
            return
        }

        // Auth check
        if !secret.isEmpty {
            let authHeader = request.headers["authorization"] ?? ""
            let expected = "Bearer \(secret)"
            if authHeader != expected {
                sendResponse(connection: connection, status: 401, body: ["error": "Unauthorized"])
                return
            }
        }

        route(request: request, connection: connection)
    }

    private func route(request: HTTPRequest, connection: NWConnection) {
        let pathComponents = request.path.split(separator: "/").map(String.init)

        let method = request.method

        if method == "GET" && pathComponents == ["status"] {
            handleStatus(connection: connection)
        } else if method == "GET" && pathComponents == ["schedules"] {
            handleListSchedules(connection: connection)
        } else if method == "GET" && pathComponents == ["history"] {
            handleHistory(connection: connection)
        } else if method == "POST" && pathComponents.count == 2 && pathComponents[0] == "trigger" {
            handleTrigger(scheduleId: pathComponents[1], connection: connection)
        } else if method == "POST" && pathComponents == ["schedule"] {
            sendResponse(connection: connection, status: 501, body: ["error": "Not implemented"])
        } else if method == "PATCH" && pathComponents.count == 2 && pathComponents[0] == "schedules" {
            handlePatchSchedule(scheduleId: pathComponents[1], body: request.body, connection: connection)
        } else {
            sendResponse(connection: connection, status: 404, body: ["error": "Not found"])
        }
    }

    // MARK: - Handlers

    private func handleStatus(connection: NWConnection) {
        let uptime = Date().timeIntervalSince(startTime)
        let scheduleCount = configManager?.config?.schedules.count ?? 0
        let version = configManager?.config?.version ?? "unknown"

        sendResponse(connection: connection, status: 200, body: [
            "status": "ok",
            "uptime": Int(uptime),
            "schedules": scheduleCount,
            "version": version
        ])
    }

    private func handleListSchedules(connection: NWConnection) {
        guard let config = configManager?.config else {
            sendResponse(connection: connection, status: 200, body: ["schedules": [Any]()])
            return
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        var scheduleList: [[String: Any]] = []
        for schedule in config.schedules {
            var entry: [String: Any] = [
                "id": schedule.id,
                "name": schedule.name,
                "enabled": schedule.enabled,
                "promptFile": schedule.promptFile,
                "time": schedule.schedule.time
            ]
            if let nextFire = schedule.nextFireDate() {
                entry["nextFireDate"] = isoFormatter.string(from: nextFire)
            }
            if let lastExec = schedulerEngine?.lastExecution[schedule.id] {
                entry["lastExecution"] = isoFormatter.string(from: lastExec)
            }
            if let days = schedule.schedule.daysOfWeek {
                entry["daysOfWeek"] = days
            }
            scheduleList.append(entry)
        }

        sendResponse(connection: connection, status: 200, body: ["schedules": scheduleList])
    }

    private func handleHistory(connection: NWConnection) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let records = schedulerEngine?.executionHistory ?? []
        let entries: [[String: Any]] = records.reversed().map { record in
            var entry: [String: Any] = [
                "scheduleId": record.scheduleId,
                "scheduleName": record.scheduleName,
                "timestamp": isoFormatter.string(from: record.timestamp),
                "success": record.success
            ]
            if let error = record.error {
                entry["error"] = error
            }
            return entry
        }

        sendResponse(connection: connection, status: 200, body: ["history": entries, "count": entries.count])
    }

    private func handleTrigger(scheduleId: String, connection: NWConnection) {
        guard let config = configManager?.config,
              config.schedules.contains(where: { $0.id == scheduleId }) else {
            sendResponse(connection: connection, status: 404, body: ["error": "Schedule '\(scheduleId)' not found"])
            return
        }

        logService?.log("HTTP trigger for schedule '\(scheduleId)'")
        schedulerEngine?.executeNow(scheduleId: scheduleId)

        sendResponse(connection: connection, status: 200, body: [
            "status": "triggered",
            "scheduleId": scheduleId
        ])
    }

    private func handlePatchSchedule(scheduleId: String, body: Data?, connection: NWConnection) {
        guard let config = configManager?.config,
              config.schedules.contains(where: { $0.id == scheduleId }) else {
            sendResponse(connection: connection, status: 404, body: ["error": "Schedule '\(scheduleId)' not found"])
            return
        }

        // Parse body for "enabled" field
        if let body = body, !body.isEmpty,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let enabled = json["enabled"] as? Bool {
            let currentlyEnabled = config.schedules.first(where: { $0.id == scheduleId })?.enabled ?? false
            if enabled != currentlyEnabled {
                configManager?.toggleSchedule(id: scheduleId)
                DispatchQueue.main.async { [weak self] in
                    self?.schedulerEngine?.restart()
                }
            }
            logService?.log("HTTP PATCH schedule '\(scheduleId)' enabled=\(enabled)")
            sendResponse(connection: connection, status: 200, body: [
                "status": "updated",
                "scheduleId": scheduleId,
                "enabled": enabled
            ])
        } else {
            sendResponse(connection: connection, status: 400, body: ["error": "Missing or invalid 'enabled' field in body"])
        }
    }

    // MARK: - Bridge Event Forwarding

    private func handleBridgeEvent(request: HTTPRequest, connection: NWConnection) {
        guard let config = bridgeForwardConfig, config.enabled else {
            sendResponse(connection: connection, status: 404, body: ["error": "Not found"])
            return
        }

        guard let bodyData = request.body, !bodyData.isEmpty else {
            sendResponse(connection: connection, status: 400, body: ["error": "Empty body"])
            return
        }

        // HMAC verification
        let secret = config.webhookSecret
        if !secret.isEmpty {
            let signature = request.headers["x-octopus-signature"] ?? ""
            let key = SymmetricKey(data: Data(secret.utf8))
            let mac = HMAC<SHA256>.authenticationCode(for: bodyData, using: key)
            let expected = "sha256=" + mac.map { String(format: "%02x", $0) }.joined()

            guard signature == expected else {
                logService?.error("Bridge event HMAC mismatch")
                sendResponse(connection: connection, status: 401, body: ["error": "Invalid signature"])
                return
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            sendResponse(connection: connection, status: 400, body: ["error": "Invalid JSON"])
            return
        }

        let eventType = (json["event"] as? String) ?? (json["type"] as? String) ?? "unknown"

        // Check event filter
        if let allowedEvents = config.forwardEvents, !allowedEvents.contains(eventType) {
            sendResponse(connection: connection, status: 200, body: ["received": true, "forwarded": false])
            return
        }

        let data = (json["data"] as? [String: Any]) ?? (json["payload"] as? [String: Any]) ?? [:]

        logService?.log("Bridge event received: \(eventType)")
        slackNotifier?.forwardBridgeEvent(type: eventType, data: data, channel: config.slackChannel)

        sendResponse(connection: connection, status: 200, body: ["received": true])
    }

    // MARK: - HTTP Parsing

    private struct HTTPRequest {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data?
    }

    private func parseHTTPRequest(data: Data) -> HTTPRequest? {
        guard let headerEndIndex = findHeaderEnd(in: data) else { return nil }

        let headerData = data[data.startIndex..<headerEndIndex]
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0])
        let fullPath = String(parts[1])
        // Strip query string
        let path = fullPath.components(separatedBy: "?").first ?? fullPath

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colonIndex].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let bodyStart = headerEndIndex + 4
        var body: Data? = nil
        if bodyStart < data.count {
            body = data[bodyStart...]
        }

        return HTTPRequest(method: method, path: path, headers: headers, body: body)
    }

    // MARK: - Response

    private func sendResponse(connection: NWConnection, status: Int, body: [String: Any]) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 404: statusText = "Not Found"
        case 501: statusText = "Not Implemented"
        default: statusText = "Error"
        }

        let jsonData = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()

        let header = [
            "HTTP/1.1 \(status) \(statusText)",
            "Content-Type: application/json",
            "Content-Length: \(jsonData.count)",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        var responseData = header.data(using: .utf8) ?? Data()
        responseData.append(jsonData)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
