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
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.4.0")
    ],
    targets: [
        .target(
            name: "PromptHubSkillKit",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .testTarget(
            name: "PromptHubSkillKitTests",
            dependencies: ["PromptHubSkillKit"]
        )
    ]
)
