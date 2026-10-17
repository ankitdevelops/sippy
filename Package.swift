// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sippy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Sippy",
            path: "Sources/Sippy",
            resources: [.copy("Resources")]
        )
    ]
)
