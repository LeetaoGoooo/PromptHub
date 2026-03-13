// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PromptHubSkillKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PromptHubSkillKit",
            targets: ["PromptHubSkillKit"]
        )
    ],
    targets: [
        .target(name: "PromptHubSkillKit"),
        .testTarget(
            name: "PromptHubSkillKitTests",
            dependencies: ["PromptHubSkillKit"]
        )
    ]
)
