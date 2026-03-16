// swift-tools-version: 6.2
import PackageDescription
let package = Package(
	name: "KataGoOnAppleSilicon",
	platforms: [.macOS(.v12), .macCatalyst(.v26)],
	products: [
		.library(
			name: "KataGoOnAppleSilicon",
			targets: ["KataGoOnAppleSilicon"]
		)
	],
	targets: [
		.target(
			name: "KataGoOnAppleSilicon",
			exclude: ["InputFeatures.md"],
			resources: [.copy("Models/Resources")]
		),
		.testTarget(
			name: "KataGoOnAppleSiliconTests",
			dependencies: ["KataGoOnAppleSilicon"]
		),
		.testTarget(
			name: "KataGoOnAppleSiliconIntegrationTests",
			dependencies: ["KataGoOnAppleSilicon"],
			resources: [.copy("ReferenceOutputs")]
		)
	]
)
