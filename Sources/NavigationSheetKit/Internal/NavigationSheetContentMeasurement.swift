import CoreGraphics

/// One screen's measured height, used to pick that screen's detent.
///
/// The sheet auto-sizes by asking each screen how tall it wants to be. Two sources answer:
/// a geometry proxy for fixed content, and scroll geometry for scrollable content. Both
/// reduce to the same three numbers, and the detent is their sum.
///
/// This type deliberately knows nothing about SwiftUI or UIKit — the arithmetic that decides
/// how tall a sheet gets is the part worth testing without a view hierarchy.
struct NavigationSheetContentMeasurement: Equatable {
  /// Path depth that produced this measurement.
  let pathDepth: Int
  /// Space above the content — a navigation bar inset, or a scroll view's top content inset.
  let topInset: CGFloat
  /// The content's own height.
  let contentHeight: CGFloat
  /// Space below the content — a bottom bar, or a scroll view's bottom content inset.
  let bottomInset: CGFloat

  /// The height to request from the sheet: `topInset + contentHeight + bottomInset`.
  ///
  /// Negative inputs are treated as zero. Callers upstream already clamp, but a detent is a
  /// height and a negative one is meaningless, so the arithmetic refuses to produce one.
  var detentHeight: CGFloat {
    max(0, topInset) + max(0, contentHeight) + max(0, bottomInset)
  }

  init(pathDepth: Int, topInset: CGFloat, contentHeight: CGFloat, bottomInset: CGFloat) {
    self.pathDepth = pathDepth
    self.topInset = topInset
    self.contentHeight = contentHeight
    self.bottomInset = bottomInset
  }
}
