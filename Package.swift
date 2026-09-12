// swift-tools-version: 6.0
import PackageDescription

// Resources are deliberately NOT declared here. SwiftPM's `resources:` generates a
// Bundle.module accessor that falls back to a hard-coded path inside the developer's
// .build directory — it works on this machine and crashes on any other. Sprites are
// copied into Contents/Resources/Sprites by scripts/build-app.sh and read via
// Bundle.main. See .scratch/coco-v1/issues/02-shipping-adhoc-app.md.
let package = Package(
    name: "Coco",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Coco", path: "Sources/Coco"),
        .testTarget(name: "CocoTests", dependencies: ["Coco"], path: "Tests/CocoTests"),
    ]
)
