// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Snaply",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Snaply",
            path: "Sources/Snaply",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
