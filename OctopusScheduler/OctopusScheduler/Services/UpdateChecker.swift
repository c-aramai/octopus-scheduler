import Foundation

struct GitHubRelease: Codable {
    let tagName: String
    let body: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

@MainActor
class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String?
    @Published var downloadURL: URL?

    let currentVersion: String

    private let releasesURL = URL(string: "https://api.github.com/repos/c-aramai/octopus-scheduler/releases/latest")!

    init() {
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() async {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latest = release.tagName.replacingOccurrences(of: "v", with: "")

            if latest.compare(currentVersion, options: .numeric) == .orderedDescending {
                self.latestVersion = latest
                self.updateAvailable = true
                if let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) {
                    self.downloadURL = URL(string: asset.browserDownloadURL)
                }
            } else {
                self.updateAvailable = false
                self.latestVersion = nil
                self.downloadURL = nil
            }
        } catch {
            print("[OctopusScheduler] Update check failed: \(error.localizedDescription)")
        }
    }
}
