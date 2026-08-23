#if os(iOS)
import Observation
import SwiftUI

/// The state one presentation shares between its UIKit spine and its SwiftUI skin.
///
/// The UIKit side — controller, detents, gestures — writes here; the SwiftUI side — the bar,
/// the screens, the replaced chrome — observes it. It exists because the two worlds need one
/// source of truth and neither's native mechanism reaches the other: preferences stop at a
/// hosting boundary, and UIKit has no environment.
@MainActor
@Observable
final class NavigationSheetModel {
  /// The current navigation depth — `0` at the root.
  var currentDepth = 0
  /// Whether the sheet is at its full height.
  var isLargeDetent = false
  /// The sheet's own safe area insets, read from the container controller's view.
  ///
  /// A known value, not a heuristic: the sheet sits on the screen's bottom edge, so its
  /// bottom inset is the home-indicator inset — zero exactly on physical-home-button devices.
  var containerInsets = EdgeInsets()

  /// Toolbar items, keyed by the depth that declared them.
  var toolbarItemsByDepth: [Int: [NavigationSheetToolbarResolvedItem]] = [:]
  /// Depths that hide the bar.
  var toolbarHiddenDepths: Set<Int> = []
  /// Depths that replaced or removed the navigation button.
  var navigationButtonsByDepth: [Int: NavigationSheetNavigationButtonOverride] = [:]
  /// Background overlays, keyed by depth.
  var backgroundOverlaysByDepth: [Int: AnyView] = [:]

  /// Appearance the caller replaced, captured at the presenting view.
  var chrome = NavigationSheetChrome()
  /// The caller's environment, re-injected into every hosted tree.
  var environment = EnvironmentValues()
  /// The registry links check before pushing, injected into every screen.
  var registry: NavigationSheetDestinationRegistry?
  /// The path binding links append to, injected into every screen.
  var pathBinding: Binding<NavigationSheetPath> = .constant(NavigationSheetPath())

  /// Pops one screen, or dismisses the sheet at the root. Wired by the controller.
  var pop: () -> Void = {}
  /// Dismisses the whole sheet. Wired by the presenter.
  var dismissSheet: () -> Void = {}

  /// Whether the bar is hidden for the screen currently showing.
  var isToolbarHidden: Bool {
    toolbarHiddenDepths.contains(currentDepth)
  }

  /// The dismiss action handed to every screen through the environment.
  var dismissAction: NavigationSheetDismissAction {
    NavigationSheetDismissAction { [weak self] behavior in
      guard let self else { return }
      switch behavior {
        case .current:
          if currentDepth == 0 {
            dismissSheet()
          } else {
            pop()
          }

        case .all:
          dismissSheet()
      }
    }
  }
}
#endif
