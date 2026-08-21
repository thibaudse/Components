#if os(iOS)
import Foundation

/// The fixed numbers the sheet's layout is built on.
///
/// They are constants rather than knobs on purpose: the bar's height feeds the detent
/// arithmetic, so a caller changing it would change how tall every screen thinks it is.
/// Appearance is replaceable; these measurements are not.
enum NavigationSheetMetrics {
  /// Duration shared by path transitions, bar transitions, and detent changes.
  static let animationDuration: TimeInterval = 0.35
  /// Height of the bar when it is visible.
  static let barHeight: CGFloat = 84
  /// Height of the drag indicator.
  static let dragIndicatorHeight: CGFloat = 4
  /// Padding above and below the drag indicator.
  static let dragIndicatorVerticalPadding: CGFloat = 8
  /// Height the bar collapses to when the toolbar is hidden — just the indicator.
  static var collapsedBarHeight: CGFloat {
    dragIndicatorHeight + dragIndicatorVerticalPadding * 2
  }
  /// Bottom padding added on devices with a physical home button, which have no home
  /// indicator to provide it.
  static let homeButtonBottomPadding: CGFloat = 20
  /// How far a transitioning or backgrounded screen is blurred.
  static let transitionBlurRadius: CGFloat = 6
}
#endif
