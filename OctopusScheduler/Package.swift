// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OctopusScheduler",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OctopusScheduler",
            path: "OctopusScheduler",
            exclude: ["Info.plist", "OctopusScheduler.entitlements", "Resources"]
        )
    ]
)
