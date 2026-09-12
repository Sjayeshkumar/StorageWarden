// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StorageWarden",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "StorageWarden", targets: ["SpaceLens"])],
    targets: [
        .executableTarget(name: "SpaceLens", path: "Sources/SpaceLens", exclude: ["App/README.md", "Resources"]),
        .testTarget(name: "SpaceLensTests", dependencies: ["SpaceLens"], path: "Tests/SpaceLensTests")
    ]
)
