// swift-tools-version:5.9
// Nur der UI-unabhängige Fachkern und dessen Tests (`swift test` unter macOS oder Linux).
// Die App wird über das mit XcodeGen erzeugte Sprachduett.xcodeproj gebaut.
import PackageDescription

let package = Package(
    name: "SprachduettCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SprachduettCore", targets: ["SprachduettCore"])],
    targets: [
        .target(
            name: "SprachduettCore",
            path: "Sprachduett/Core",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SprachduettTests",
            dependencies: ["SprachduettCore"],
            path: "SprachduettTests"
        ),
    ]
)
