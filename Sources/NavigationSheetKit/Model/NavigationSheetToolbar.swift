#if os(iOS)
import SwiftUI

/// Where a toolbar item sits in a navigation sheet's bar.
public enum NavigationSheetToolbarPlacement: Sendable {
  /// Leading items, after the navigation button.
  case topBarLeading
  /// The centered title item.
  case title
  /// Trailing items.
  case topBarTrailing
}

/// Whether a piece of navigation sheet chrome is shown.
public enum NavigationSheetToolbarVisibility: Sendable {
  case visible
  case hidden
}

/// Whether a navigation sheet toolbar item gets the default detent-adaptive button style.
///
/// By default toolbar buttons are styled for you, the way SwiftUI's own toolbar styles
/// its buttons: `.bordered`, becoming `.glass` at the large detent on iOS 26 and later.
/// Opt out with ``hidden`` and apply your own `.buttonStyle(_:)`.
public enum NavigationSheetToolbarButtonStyle: Equatable, Sendable {
  /// The default: `.bordered`, or `.glass` at the large detent on iOS 26 and later.
  case automatic
  /// No style is applied. You are responsible for styling the item's buttons.
  case hidden
}

/// The preferred detent for one navigation sheet screen.
public enum NavigationSheetPreferredDetent: Equatable, Sendable {
  /// The sheet measures the screen's content and picks a matching detent. The default.
  case automatic
  /// Forces a specific presentation detent for this screen.
  case detent(_ value: PresentationDetent)
}
#endif
