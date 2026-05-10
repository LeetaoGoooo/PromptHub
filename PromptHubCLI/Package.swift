// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PromptHubCLI",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "prompthub", targets: ["prompthub-cli"]),
        .library(name: "PromptHubCLILib", targets: ["PromptHubCLILib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
    ],
    targets: [
        // Library target — all business logic, easily unit-tested
        .target(
            name: "PromptHubCLILib",
            dependencies: [],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        // Executable — thin entry point, delegates to PromptHubCLILib
        .executableTarget(
            name: "prompthub-cli",
            dependencies: [
                "PromptHubCLILib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/prompthub-cli"
        ),
        .testTarget(
            name: "PromptHubCLITests",
            dependencies: ["PromptHubCLILib"],
            path: "Tests/PromptHubCLITests"
        ),
    ]
)
