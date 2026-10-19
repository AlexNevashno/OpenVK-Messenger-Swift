// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenVKMessenger",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "OpenVKMessenger",
            targets: ["OpenVKMessenger"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OpenVKMessenger",
            path: "Sources/OpenVKMessenger"
        )
    ]
)
