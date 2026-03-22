// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MenuBarStats",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MenuBarStats",
            path: "Sources/MenuBarStats",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "MenuBarStatsTests",
            dependencies: ["MenuBarStats"],
            path: "Tests/MenuBarStatsTests"
        )
    ]
)
