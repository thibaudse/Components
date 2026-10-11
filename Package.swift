// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Components",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v18),
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "AdaptiveSheetKit",
      targets: ["AdaptiveSheetKit"]
    ),
    .library(
      name: "CalendarKit",
      targets: ["CalendarKit"]
    ),
    .library(
      name: "NavigationSheetKit",
      targets: ["NavigationSheetKit"]
    )
  ],
  targets: [
    .target(
      name: "AdaptiveSheetKit"
    ),
    .testTarget(
      name: "AdaptiveSheetKitTests",
      dependencies: ["AdaptiveSheetKit"]
    ),
    .target(
      name: "CalendarKit",
      resources: [
        .process("Resources/Localizable.xcstrings")
      ]
    ),
    .testTarget(
      name: "CalendarKitTests",
      dependencies: ["CalendarKit"]
    ),
    .target(
      name: "NavigationSheetKit",
      resources: [
        .process("Resources/Localizable.xcstrings")
      ]
    ),
    .testTarget(
      name: "NavigationSheetKitTests",
      dependencies: ["NavigationSheetKit"]
    )
  ]
)
