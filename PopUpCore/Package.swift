// swift-tools-version: 5.9
import PackageDescription

// Game logic with no UIKit or SceneKit in it, so it builds and tests anywhere,
// including `swift test` on Linux.
let package = Package(
    name: "PopUpCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PopUpCore", targets: ["PopUpCore"]),
    ],
    targets: [
        .target(name: "PopUpCore"),
        .testTarget(name: "PopUpCoreTests", dependencies: ["PopUpCore"]),
    ]
)
