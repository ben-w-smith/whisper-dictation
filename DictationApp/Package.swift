// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DictationApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DictationApp", targets: ["DictationApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "DictationApp",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "DictationApp",
            exclude: ["Resources/Info.plist"],
            resources: [
                .copy("Resources/providers.json")
            ]
        )
    ]
)
