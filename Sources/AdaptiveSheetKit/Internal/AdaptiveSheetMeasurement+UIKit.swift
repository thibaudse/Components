#if os(iOS)
import UIKit

extension AdaptiveSheetMeasurement {
  /// Creates the measurement of a screen whose content scrolls, read straight off its scroll view.
  ///
  /// For a screen inside a `NavigationStack`, where SwiftUI's own measurement cannot say which screen is
  /// on top. **The bar's height is passed in rather than read off the scroll view's adjusted insets**:
  /// those carry the safe area, which reaches a freshly shown screen a layout pass after its content
  /// does, so reading them measured every screen short by the bar first and corrected it a frame later.
  /// The bottom safe area is the home indicator's and is left out, as everywhere; only the scroll view's
  /// own insets — content margins — are counted.
  ///
  /// - Parameters:
  ///   - scrollView: The scroll view that fills the screen.
  ///   - barHeight: How far the navigation bar reaches down the sheet, or zero while it is hidden.
  @MainActor
  init(scrollView: UIScrollView, barHeight: CGFloat) {
    self.init(
      topInset: max(0, barHeight) + max(0, scrollView.contentInset.top),
      contentHeight: max(0, scrollView.contentSize.height),
      bottomInset: max(0, scrollView.contentInset.bottom)
    )
  }

  /// Creates the measurement of a screen that does not scroll: its view's fitting height under the bar.
  ///
  /// **A hosting view's fitting height includes its safe area**, top and bottom — a three-row screen
  /// whose content is 192pt fits at 348 under a 122pt top inset and the 34pt home indicator. Both come
  /// off: the bar is added back as `barHeight`, which settles before the safe area does, and the home
  /// indicator is the presentation's to reserve, as everywhere.
  ///
  /// - Parameters:
  ///   - screenView: The screen's root view, as its view controller holds it.
  ///   - barHeight: How far the navigation bar reaches down the sheet, or zero while it is hidden.
  @MainActor
  init(screenView: UIView, barHeight: CGFloat) {
    let fitting = screenView.sizeThatFits(
      CGSize(width: screenView.bounds.width, height: .greatestFiniteMagnitude)
    )
    let safeArea = screenView.safeAreaInsets

    self.init(
      topInset: max(0, barHeight),
      contentHeight: max(0, fitting.height - safeArea.top - safeArea.bottom),
      bottomInset: 0
    )
  }
}
#endif
