// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PromptHubCLI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PromptHubCLILib",
            targets: ["PromptHubCLILib"]
        ),
        .executable(
            name: "ph",
            targets: ["PromptHubCLIExecutable"]
        )
    ],
    dependencies: [
        .package(path: "../PromptHubSkillKit"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.1"),
        .package(url: "https://github.com/swiftlang/swift-testing", exact: "0.99.0")
    ],
    targets: [
        .target(
            name: "PromptHubCLILib",
            dependencies: [
                "PromptHubSkillKit"
            ],
            path: "Sources/PromptHubCLILib"
        ),
        .executableTarget(
            name: "PromptHubCLIExecutable",
            dependencies: [
                "PromptHubCLILib",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/prompthub-cli"
        ),
        .testTarget(
            name: "PromptHubCLITests",
            dependencies: [
                "PromptHubCLILib",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/PromptHubCLITests"
        )
    ]
)
