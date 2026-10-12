// swift-tools-version:5.9
// https://github.com/ziqq/Glimpshot
// Copyright (C) 2026 Anton Ustinoff
// https://github.com/ziqq/Glimpshot/blob/main/LICENSE

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
