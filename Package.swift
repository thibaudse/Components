// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Components",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17),
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "CalendarKit",
      targets: ["CalendarKit"]
    )
  ],
  targets: [
    .target(
      name: "CalendarKit",
      resources: [
        .process("Resources/Localizable.xcstrings")
      ]
    ),
    .testTarget(
      name: "CalendarKitTests",
      dependencies: ["CalendarKit"]
    )
  ]
)
