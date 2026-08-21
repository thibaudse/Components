#if os(iOS)
import SwiftUI

extension EnvironmentValues {
  /// The registry the sheet resolves destinations through.
  @Entry var navigationSheetRegistry: NavigationSheetDestinationRegistry?

  /// A binding to the enclosing sheet's path, so links can push onto it.
  @Entry var navigationSheetPath: Binding<NavigationSheetPath> = .constant(NavigationSheetPath())

  /// The default button style applied to this screen's toolbar items.
  @Entry var navigationSheetToolbarButtonStyle: NavigationSheetToolbarButtonStyle = .automatic

  /// The chrome a caller has replaced, carried from the presenting view into the sheet.
  @Entry var navigationSheetChrome = NavigationSheetChrome()

  /// The hosting window's safe area insets, resolved by the sheet itself.
  ///
  /// Not the sheet's own insets: a sheet gets whatever the presentation gives it, while the
  /// layout inside depends on whether the *device* has a home indicator.
  @Entry var navigationSheetWindowInsets = EdgeInsets()
}

public extension EnvironmentValues {
  /// Dismisses the current navigation sheet screen, or the whole sheet.
  ///
  /// See ``NavigationSheetDismissAction``.
  @Entry var navigationSheetDismiss = NavigationSheetDismissAction()

  /// How deep into the sheet's path this view sits — `0` at the root.
  ///
  /// Useful when one screen is pushed from several places and needs to know whether it is
  /// the root, for instance to choose its own navigation button.
  @Entry var navigationSheetPathDepth = 0

  /// Whether the enclosing navigation sheet is currently at its large detent.
  ///
  /// The sheet's own chrome adapts to this, and so can yours: it is what distinguishes a
  /// sheet filling the screen from one sized to a short screen's content.
  @Entry var navigationSheetIsLargeDetent = false
}
#endif
