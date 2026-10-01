// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Glimpshot",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Glimpshot",
            path: "Sources/Glimpshot",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
