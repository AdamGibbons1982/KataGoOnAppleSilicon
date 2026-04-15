// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "KataGoOnAppleSilicon",
    platforms: [.macOS(.v12), .macCatalyst(.v26), .iOS(.v26)],
    products: [
        .library(
            name: "KataGoOnAppleSilicon",
            targets: ["KataGoOnAppleSilicon"]
        ),
        .executable(name: "KataGoPlay", targets: ["KataGoPlay"]),
    ],
    targets: [
        .target(
            name: "KataGoOnAppleSilicon",
            exclude: ["InputFeatures.md"],
            resources: [.process("Models/Resources")]
        ),
        .executableTarget(
            name: "KataGoPlay",
            dependencies: ["KataGoOnAppleSilicon"],
            path: "Sources/KataGoPlay"
        ),
        .testTarget(
            name: "KataGoOnAppleSiliconTests",
            dependencies: ["KataGoOnAppleSilicon"]
        ),
        .testTarget(
            name: "KataGoOnAppleSiliconIntegrationTests",
            dependencies: ["KataGoOnAppleSilicon"],
            resources: [.copy("ReferenceOutputs")]
        ),
    ]
)
