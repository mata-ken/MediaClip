// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MediaClip",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MediaClip",
            path: "MediaClip",
            exclude: ["App/Info.plist", "Resources/MediaClip.entitlements"],
            resources: [
                .process("Resources/Assets.xcassets"),
            ]
        ),
    ]
)
