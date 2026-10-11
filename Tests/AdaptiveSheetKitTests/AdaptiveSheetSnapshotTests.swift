import CoreGraphics
import Testing

@testable import AdaptiveSheetKit

// The order plain geometry and scroll geometry report in is SwiftUI's, and either can come first — so
// each keyboard transition is replayed both ways.
struct AdaptiveSheetSnapshotTests {
  /// Which of a transition's two readings arrives first.
  enum Order: CaseIterable {
    case layoutFirst
    case scrollFirst
  }

  private static let homeIndicator: CGFloat = 34
  private static let keyboard: CGFloat = 336
  private static let contentHeight: CGFloat = 300

  private static func layout(containerBottomInset: CGFloat) -> AdaptiveSheetSnapshot.Layout {
    AdaptiveSheetSnapshot.Layout(
      measurement: AdaptiveSheetMeasurement(topInset: 0, contentHeight: 600, bottomInset: 0),
      containerBottomInset: containerBottomInset
    )
  }

  private static func scrollReading(bottomInset: CGFloat) -> AdaptiveSheetMeasurement {
    AdaptiveSheetMeasurement(topInset: 0, contentHeight: contentHeight, bottomInset: bottomInset)
  }

  /// A content-hugging scroll view, settled at rest over the home indicator.
  private static func settledAtRest() -> AdaptiveSheetSnapshot {
    var snapshot = AdaptiveSheetSnapshot(layout: layout(containerBottomInset: homeIndicator))
    snapshot.take(scrollReading: scrollReading(bottomInset: homeIndicator))
    return snapshot
  }

  /// Moves the container's bottom inset to `inset` — the keyboard arriving or leaving — and returns the
  /// bottom inset the sheet was sized with after each of the two readings.
  private static func transition(
    _ snapshot: inout AdaptiveSheetSnapshot,
    to inset: CGFloat,
    order: Order
  ) -> [CGFloat] {
    switch order {
    case .layoutFirst:
      snapshot.take(layout(containerBottomInset: inset))
      let first = snapshot.measurement.bottomInset
      snapshot.take(scrollReading: scrollReading(bottomInset: inset))
      return [first, snapshot.measurement.bottomInset]
    case .scrollFirst:
      snapshot.take(scrollReading: scrollReading(bottomInset: inset))
      let first = snapshot.measurement.bottomInset
      snapshot.take(layout(containerBottomInset: inset))
      return [first, snapshot.measurement.bottomInset]
    }
  }

  // The bug: the keyboard's inset left behind as content inset, and the high-water mark keeping it, so
  // the sheet stayed tall after the keyboard had gone.
  @Test(arguments: Order.allCases, Order.allCases)
  func keyboardLeavingShrinksTheSheetBack(opening: Order, closing: Order) {
    var snapshot = Self.settledAtRest()

    _ = Self.transition(&snapshot, to: Self.keyboard, order: opening)
    _ = Self.transition(&snapshot, to: Self.homeIndicator, order: closing)

    #expect(snapshot.measurement.bottomInset == 0)
    #expect(snapshot.measurement.detentHeight == Self.contentHeight)
  }

  // The leaving keyboard's inset, recomputed off the last scroll reading, read as a 302pt bump for the
  // frame before the scroll view's own reading arrived.
  @Test(arguments: Order.allCases)
  func keyboardLeavingNeverGrowsTheSheetOnTheWay(closing: Order) {
    var snapshot = Self.settledAtRest()
    _ = Self.transition(&snapshot, to: Self.keyboard, order: .layoutFirst)

    let steps = Self.transition(&snapshot, to: Self.homeIndicator, order: closing)

    #expect(steps == [0, 0])
  }

  @Test(arguments: Order.allCases)
  func repeatedKeyboardCyclesSettleAtRest(order: Order) {
    var snapshot = Self.settledAtRest()

    for _ in 1...3 {
      _ = Self.transition(&snapshot, to: Self.keyboard, order: order)
      _ = Self.transition(&snapshot, to: Self.homeIndicator, order: order)
    }

    #expect(snapshot.measurement.bottomInset == 0)
  }

  // The home indicator can reach the sheet's safe area a pass after the first scroll reading.
  @Test func lateHomeIndicatorComesOffTheBottomInset() {
    var snapshot = AdaptiveSheetSnapshot(layout: Self.layout(containerBottomInset: 0))
    snapshot.take(scrollReading: Self.scrollReading(bottomInset: Self.homeIndicator))
    #expect(snapshot.measurement.bottomInset == Self.homeIndicator)

    snapshot.take(Self.layout(containerBottomInset: Self.homeIndicator))

    #expect(snapshot.measurement.bottomInset == 0)
  }

  // Detent-driven churn in the scroll view's insets is still damped while the container stays put.
  @Test func bottomInsetHoldsItsMarkWhileTheContainerStaysPut() {
    var snapshot = Self.settledAtRest()
    snapshot.take(scrollReading: Self.scrollReading(bottomInset: Self.homeIndicator + 20))

    snapshot.take(scrollReading: Self.scrollReading(bottomInset: Self.homeIndicator + 8))

    #expect(snapshot.measurement.bottomInset == 20)
  }

  // A new container inset is not detent churn: the next scroll reading is taken as it is.
  @Test func newContainerInsetRestartsTheMark() {
    var snapshot = Self.settledAtRest()
    snapshot.take(scrollReading: Self.scrollReading(bottomInset: Self.homeIndicator + 20))
    snapshot.take(Self.layout(containerBottomInset: Self.keyboard))

    snapshot.take(scrollReading: Self.scrollReading(bottomInset: Self.keyboard + 8))

    #expect(snapshot.measurement.bottomInset == 8)
  }

  // Before scroll geometry has spoken, plain geometry is the measurement.
  @Test func layoutReadingsReplaceEachOtherUntilTheScrollViewReports() {
    var snapshot = AdaptiveSheetSnapshot(layout: Self.layout(containerBottomInset: 0))
    let later = AdaptiveSheetSnapshot.Layout(
      measurement: AdaptiveSheetMeasurement(topInset: 12, contentHeight: 240, bottomInset: 0),
      containerBottomInset: Self.homeIndicator
    )

    snapshot.take(later)

    #expect(snapshot.measurement == later.measurement)
    #expect(snapshot.containerBottomInset == Self.homeIndicator)
  }
}
