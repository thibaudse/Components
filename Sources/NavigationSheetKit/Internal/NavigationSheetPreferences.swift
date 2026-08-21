#if os(iOS)
import SwiftUI

// Everything a screen tells the sheet about itself travels as a preference, keyed by the
// screen's path depth. Preferences flow outward, which is the only direction that works
// here: the bar, the detents, and the sheet background are all owned by the container that
// *hosts* the screens, so the screens cannot reach them through the environment.

// MARK: - Toolbar Items

/// A toolbar item resolved to its rendered content.
struct NavigationSheetToolbarResolvedItem: Equatable {
  /// Stable identifier, used to key the bar's transitions.
  let id: String
  let placement: NavigationSheetToolbarPlacement
  let pathDepth: Int
  let content: AnyView

  // AnyView is not Equatable, so identity stands in for the content: two items with the
  // same id at the same place and depth are the same item, however it re-renders.
  static func == (lhs: NavigationSheetToolbarResolvedItem, rhs: NavigationSheetToolbarResolvedItem) -> Bool {
    lhs.id == rhs.id && lhs.placement == rhs.placement && lhs.pathDepth == rhs.pathDepth
  }
}

struct NavigationSheetToolbarItemsKey: PreferenceKey {
  static var defaultValue: [NavigationSheetToolbarResolvedItem] { [] }

  static func reduce(value: inout [NavigationSheetToolbarResolvedItem], nextValue: () -> [NavigationSheetToolbarResolvedItem]) {
    value.append(contentsOf: nextValue())
  }
}

// MARK: - Detents

struct NavigationSheetDetentPreferenceItem: Equatable {
  let pathDepth: Int
  let detent: NavigationSheetPreferredDetent
}

struct NavigationSheetDetentKey: PreferenceKey {
  static let defaultValue = [NavigationSheetDetentPreferenceItem]()

  static func reduce(value: inout [NavigationSheetDetentPreferenceItem], nextValue: () -> [NavigationSheetDetentPreferenceItem]) {
    value.append(contentsOf: nextValue())
  }
}

// MARK: - Toolbar Visibility

/// The depths whose bar is hidden.
struct NavigationSheetToolbarHiddenKey: PreferenceKey {
  static let defaultValue = [Int]()

  static func reduce(value: inout [Int], nextValue: () -> [Int]) {
    value.append(contentsOf: nextValue())
  }
}

// MARK: - Navigation Button

/// A screen's replacement for the bar's built-in navigation button.
enum NavigationSheetNavigationButtonOverride {
  /// No navigation button at all.
  case hidden
  /// This content in place of the default.
  case custom(AnyView)
}

struct NavigationSheetNavigationButtonItem: Equatable {
  let pathDepth: Int
  let override: NavigationSheetNavigationButtonOverride

  static func == (lhs: NavigationSheetNavigationButtonItem, rhs: NavigationSheetNavigationButtonItem) -> Bool {
    guard lhs.pathDepth == rhs.pathDepth else { return false }
    switch (lhs.override, rhs.override) {
      case (.hidden, .hidden), (.custom, .custom):
        return true

      default:
        return false
    }
  }
}

struct NavigationSheetNavigationButtonKey: PreferenceKey {
  static var defaultValue: [NavigationSheetNavigationButtonItem] { [] }

  static func reduce(value: inout [NavigationSheetNavigationButtonItem], nextValue: () -> [NavigationSheetNavigationButtonItem]) {
    value.append(contentsOf: nextValue())
  }
}

// MARK: - Background Overlay

struct NavigationSheetBackgroundOverlayItem: Equatable {
  let pathDepth: Int
  let content: AnyView

  static func == (lhs: NavigationSheetBackgroundOverlayItem, rhs: NavigationSheetBackgroundOverlayItem) -> Bool {
    lhs.pathDepth == rhs.pathDepth
  }
}

struct NavigationSheetBackgroundOverlayKey: PreferenceKey {
  static var defaultValue: [NavigationSheetBackgroundOverlayItem] { [] }

  static func reduce(value: inout [NavigationSheetBackgroundOverlayItem], nextValue: () -> [NavigationSheetBackgroundOverlayItem]) {
    value.append(contentsOf: nextValue())
  }
}

// MARK: - Content Measurement

struct NavigationSheetContentMeasurementKey: PreferenceKey {
  static let defaultValue = [NavigationSheetContentMeasurement]()

  static func reduce(value: inout [NavigationSheetContentMeasurement], nextValue: () -> [NavigationSheetContentMeasurement]) {
    value.append(contentsOf: nextValue())
  }
}
#endif
