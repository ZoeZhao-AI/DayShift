// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DayShiftKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DayShiftKit", targets: ["DayShiftKit"])
    ],
    targets: [
        .target(name: "DayShiftKit"),
        .testTarget(name: "DayShiftKitTests", dependencies: ["DayShiftKit"])
    ]
)
