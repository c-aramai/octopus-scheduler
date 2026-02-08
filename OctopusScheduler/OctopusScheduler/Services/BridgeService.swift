import Foundation
import Combine

enum BridgeStatus {
    case connected, disconnected, notConfigured
}

struct BridgePeer: Codable {
    let peerId: String
    let lastSeen: String?
    let status: String?
}

class BridgeService: ObservableObject {
    @Published var status: BridgeStatus = .notConfigured
    @Published var peers: [BridgePeer] = []

    private var timer: Timer?
    private var bridgeUrl: String?

    func configure(bridgeUrl: String?) {
        self.bridgeUrl = bridgeUrl
        if bridgeUrl == nil || bridgeUrl?.isEmpty == true {
            status = .notConfigured
            peers = []
        }
    }

    func startPolling(interval: TimeInterval = 30) {
        timer?.invalidate()
        guard bridgeUrl != nil else { return }
        syncNow()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.syncNow()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func syncNow() {
        checkHealth()
        fetchPeers()
    }

    private func checkHealth() {
        guard let urlStr = bridgeUrl, let url = URL(string: "\(urlStr)/api/health") else {
            DispatchQueue.main.async { self.status = .notConfigured }
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200, error == nil {
                    self?.status = .connected
                } else {
                    self?.status = .disconnected
                }
            }
        }.resume()
    }

    private func fetchPeers() {
        guard let urlStr = bridgeUrl, let url = URL(string: "\(urlStr)/api/peers?stale=true") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let data = data,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let decoded = try? JSONDecoder().decode([BridgePeer].self, from: data) else {
                DispatchQueue.main.async { self?.peers = [] }
                return
            }
            DispatchQueue.main.async { self?.peers = decoded }
        }.resume()
    }
}
