// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SplashMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SplashMonitor",
            targets: ["SplashMonitor"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SplashMonitor",
            dependencies: [],
            path: "Sources/SplashMonitor"
        )
    ]
)
