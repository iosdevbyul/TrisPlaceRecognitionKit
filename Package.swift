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
            branch: "main"
        )
    ],
    targets: [
        .target(
            name: "TrisPlaceRecognitionKit",
            dependencies: [
                .product(
                    name: "TrisLocationKit",
                    package: "TrisLocationKit"
                )
            ]
        ),
        .testTarget(
            name: "TrisPlaceRecognitionKitTests",
            dependencies: [
                "TrisPlaceRecognitionKit"
            ]
        )
    ]
)
