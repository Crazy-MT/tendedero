// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PegNest",
    platforms: [.macOS(.v14)],
    targets: [
        // Resources holds the translations. scripts/build-app.sh copies them
        // into the app, so SwiftPM leaves them alone.
        .executableTarget(name: "PegNest", path: "Sources/PegNest", exclude: ["Resources"]),
        .testTarget(name: "PegNestTests", dependencies: ["PegNest"])
    ]
)
