// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TrisPlaceRecognitionKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "TrisPlaceRecognitionKit",
            targets: [
                "TrisPlaceRecognitionKit"
            ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/iosdevbyul/TrisLocationKit",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/iosdevbyul/TrisNotificationKit",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "TrisPlaceRecognitionKit",
            dependencies: [
                .product(
                    name: "TrisLocationKit",
                    package: "TrisLocationKit"
                ),
                .product(
                    name: "TrisNotificationKit",
                    package: "TrisNotificationKit"
                )
            ],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "TrisPlaceRecognitionKitTests",
            dependencies: [
                "TrisPlaceRecognitionKit"
            ],
            resources: [
                .copy("Fixtures/LegacySwiftDataV1")
            ]
        )
    ]
)
