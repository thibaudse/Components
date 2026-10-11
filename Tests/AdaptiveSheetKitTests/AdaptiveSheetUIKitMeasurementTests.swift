#if os(iOS)
import Testing
import UIKit

@testable import AdaptiveSheetKit

// Against real UIKit views, off-window, so each test states the geometry a sheet would hand it.
@MainActor
struct AdaptiveSheetUIKitMeasurementTests {
  private static func makeScrollView(contentHeight: CGFloat, top: CGFloat, bottom: CGFloat) -> UIScrollView {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.contentInset = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
    scrollView.contentSize = CGSize(width: 402, height: contentHeight)
    return scrollView
  }

  // The bar is passed in, not read off the adjusted insets, which reach a new screen a pass late.
  @Test func scrollViewSitsUnderTheBar() {
    let scrollView = Self.makeScrollView(contentHeight: 192, top: 0, bottom: 0)

    let measurement = AdaptiveSheetMeasurement(scrollView: scrollView, barHeight: 70)

    #expect(measurement.detentHeight == 262)
  }

  // Content margins are the scroll view's own insets and belong in the sheet.
  @Test func scrollViewCountsItsOwnInsets() {
    let scrollView = Self.makeScrollView(contentHeight: 192, top: 8, bottom: 16)

    let measurement = AdaptiveSheetMeasurement(scrollView: scrollView, barHeight: 70)

    #expect(measurement.topInset == 78)
    #expect(measurement.bottomInset == 16)
    #expect(measurement.detentHeight == 286)
  }

  @Test func screenViewIsItsFittingHeight() {
    let view = FixedFittingView(fittingHeight: 240)

    let measurement = AdaptiveSheetMeasurement(screenView: view, barHeight: 70)

    #expect(measurement.detentHeight == 310)
  }

  // A hosting view fits at its content plus its safe area — 192 of rows under a 122pt top inset and
  // the home indicator read as 348. Counted as content, the bar and the indicator were paid twice.
  @Test func screenViewLeavesOutItsSafeArea() {
    let view = FixedFittingView(
      fittingHeight: 348,
      safeArea: UIEdgeInsets(top: 122, left: 0, bottom: 34, right: 0)
    )

    let measurement = AdaptiveSheetMeasurement(screenView: view, barHeight: 70)

    #expect(measurement.contentHeight == 192)
    #expect(measurement.detentHeight == 262)
  }
}

/// A view that fits at a known height under a known safe area, standing in for a hosted SwiftUI screen.
private final class FixedFittingView: UIView {
  private let fittingHeight: CGFloat
  private let safeArea: UIEdgeInsets

  init(fittingHeight: CGFloat, safeArea: UIEdgeInsets = .zero) {
    self.fittingHeight = fittingHeight
    self.safeArea = safeArea
    super.init(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
  }

  override var safeAreaInsets: UIEdgeInsets {
    safeArea
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: size.width, height: fittingHeight)
  }
}
#endif
