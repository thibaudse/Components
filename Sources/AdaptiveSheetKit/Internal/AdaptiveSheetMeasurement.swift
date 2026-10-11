import CoreGraphics

/// How tall an adaptive sheet's content wants to be, and the detent that follows from it.
///
/// Three sources answer: a geometry proxy for static content, scroll geometry for a scroll view — whose
/// frame is only ever the height the sheet already gave it — and, for the screen on top of a
/// `NavigationStack`, UIKit's own reading of it (`AdaptiveSheetMeasurement+UIKit.swift`). All reduce
/// to the same three numbers, and the detent is their sum. The type itself knows nothing about SwiftUI
/// or UIKit on purpose — the arithmetic that decides how tall a sheet gets is the part worth testing
/// without a hierarchy.
struct AdaptiveSheetMeasurement: Equatable {
  /// Space above the content — the sheet's top safe area, or a scroll view's top content inset.
  let topInset: CGFloat
  /// The content's own height.
  let contentHeight: CGFloat
  /// Space below the content — a scroll view's bottom content inset, less what the presentation
  /// already reserves for the home indicator.
  let bottomInset: CGFloat

  /// The height to ask the sheet for: `topInset + contentHeight + bottomInset`.
  ///
  /// A negative input counts as zero. The callers clamp already, but a detent is a height and a
  /// negative one is meaningless, so the arithmetic refuses to produce one.
  var detentHeight: CGFloat {
    max(0, topInset) + max(0, contentHeight) + max(0, bottomInset)
  }

  /// Creates a measurement from the three numbers directly.
  init(topInset: CGFloat, contentHeight: CGFloat, bottomInset: CGFloat) {
    self.topInset = topInset
    self.contentHeight = contentHeight
    self.bottomInset = bottomInset
  }

  /// Creates the measurement a scroll view's raw reading settles to.
  ///
  /// The presentation already reserves the home indicator's inset, so a scroll view's copy of it is
  /// subtracted rather than paid twice. The bottom inset is then a high-water mark over `previous`,
  /// because the detent changes the scroll view's insets, which would otherwise change the detent:
  /// without it the two oscillate.
  ///
  /// - Parameters:
  ///   - reading: The scroll view's content insets and content height, as reported.
  ///   - containerBottomInset: The home indicator's inset, from the sheet's safe area.
  ///   - previous: The last measurement taken from scroll geometry, or `nil` for the first.
  init(
    scrollReading reading: AdaptiveSheetMeasurement,
    containerBottomInset: CGFloat,
    previous: AdaptiveSheetMeasurement?
  ) {
    let scrollBottom = max(0, reading.bottomInset - containerBottomInset)

    self.init(
      topInset: reading.topInset,
      contentHeight: reading.contentHeight,
      bottomInset: max(scrollBottom, previous?.bottomInset ?? 0)
    )
  }

  /// The detent height, rounded up to the pixel grid and capped at the tallest the sheet can be.
  ///
  /// **Rounded up, never to the nearest.** A measurement is fractional — 300.1 of content — and the
  /// sheet lands on whole pixels. Rounded down by even part of a pixel, a scroll view that fits is
  /// left a sliver taller than its frame and scrolls. Content taller than the screen stops at the
  /// large detent; scrolling past it is the caller's.
  ///
  /// - Parameters:
  ///   - maximumHeight: The tallest the sheet can be.
  ///   - displayScale: Pixels per point. Zero or less rounds up to whole points.
  func detentHeight(cappedAt maximumHeight: CGFloat, displayScale: CGFloat) -> CGFloat {
    let scale = displayScale > 0 ? displayScale : 1
    let rounded = (detentHeight * scale).rounded(.up) / scale
    return min(rounded, max(0, maximumHeight))
  }
}
