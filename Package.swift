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
      name: "CardSheetKit",
      targets: ["CardSheetKit"]
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
      name: "CardSheetKit",
      dependencies: ["CardSheetKitObjC"]
    ),
    // Swift cannot catch an Objective-C exception, and private UIKit can raise one.
    .target(
      name: "CardSheetKitObjC"
    ),
    .testTarget(
      name: "CardSheetKitTests",
      dependencies: ["CardSheetKit"]
    )
  ]
)
