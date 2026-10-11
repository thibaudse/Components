import CoreGraphics
import Testing

@testable import AdaptiveSheetKit

struct AdaptiveSheetMeasurementTests {
  @Test func detentIsTheSumOfItsParts() {
    let measurement = AdaptiveSheetMeasurement(topInset: 24, contentHeight: 300, bottomInset: 16)

    #expect(measurement.detentHeight == 340)
  }

  @Test func negativePartsCountAsZero() {
    let measurement = AdaptiveSheetMeasurement(topInset: -10, contentHeight: 200, bottomInset: -5)

    #expect(measurement.detentHeight == 200)
  }

  @Test(arguments: [
    (maximum: 800, expected: 340),
    (maximum: 300, expected: 300),
    (maximum: -1, expected: 0),
  ] as [(maximum: CGFloat, expected: CGFloat)])
  func capsAtTheTallestTheSheetCanBe(maximum: CGFloat, expected: CGFloat) {
    let measurement = AdaptiveSheetMeasurement(topInset: 24, contentHeight: 300, bottomInset: 16)

    #expect(measurement.detentHeight(cappedAt: maximum, displayScale: 3) == expected)
  }

  // Rounded down, a scroll view that fits was left a fraction of a point taller than its frame, and
  // scrolled.
  @Test(arguments: [
    (content: 300.1, scale: 3, expected: 901.0 / 3),
    (content: 300.1, scale: 2, expected: 300.5),
    (content: 300.1, scale: 0, expected: 301),
    (content: 300.0, scale: 3, expected: 300),
  ] as [(content: CGFloat, scale: CGFloat, expected: CGFloat)])
  func roundsUpToThePixelGrid(content: CGFloat, scale: CGFloat, expected: CGFloat) {
    let measurement = AdaptiveSheetMeasurement(topInset: 0, contentHeight: content, bottomInset: 0)

    let height = measurement.detentHeight(cappedAt: 800, displayScale: scale)

    #expect(height >= content)
    #expect(height == expected)
  }

  // Counted in the scroll view's insets as well as the presentation's, the home indicator's inset
  // left an empty band under the content.
  @Test func scrollReadingLeavesOutTheHomeIndicator() {
    let reading = AdaptiveSheetMeasurement(topInset: 0, contentHeight: 300, bottomInset: 34)

    let measurement = AdaptiveSheetMeasurement(scrollReading: reading, containerBottomInset: 34, previous: nil)

    #expect(measurement.bottomInset == 0)
    #expect(measurement.detentHeight == 300)
  }

  @Test func scrollReadingNeverGoesBelowZero() {
    let reading = AdaptiveSheetMeasurement(topInset: 0, contentHeight: 300, bottomInset: 10)

    let measurement = AdaptiveSheetMeasurement(scrollReading: reading, containerBottomInset: 34, previous: nil)

    #expect(measurement.bottomInset == 0)
  }

  // Resizing the sheet shrinks the scroll view's bottom inset; following it down would resize the
  // sheet again, and the two would oscillate.
  @Test func bottomInsetHoldsItsHighWaterMark() {
    let previous = AdaptiveSheetMeasurement(topInset: 0, contentHeight: 300, bottomInset: 20)
    let reading = AdaptiveSheetMeasurement(topInset: 0, contentHeight: 300, bottomInset: 34 + 8)

    let measurement = AdaptiveSheetMeasurement(scrollReading: reading, containerBottomInset: 34, previous: previous)

    #expect(measurement.bottomInset == 20)
  }

  @Test func bottomInsetRisesPastItsHighWaterMark() {
    let previous = AdaptiveSheetMeasurement(topInset: 0, contentHeight: 300, bottomInset: 20)
    let reading = AdaptiveSheetMeasurement(topInset: 0, contentHeight: 300, bottomInset: 34 + 30)

    let measurement = AdaptiveSheetMeasurement(scrollReading: reading, containerBottomInset: 34, previous: previous)

    #expect(measurement.bottomInset == 30)
  }

  // Only the bottom inset is a high-water mark: content that shrinks still shrinks the sheet.
  @Test func contentHeightFollowsTheReading() {
    let previous = AdaptiveSheetMeasurement(topInset: 0, contentHeight: 500, bottomInset: 20)
    let reading = AdaptiveSheetMeasurement(topInset: 12, contentHeight: 200, bottomInset: 34)

    let measurement = AdaptiveSheetMeasurement(scrollReading: reading, containerBottomInset: 34, previous: previous)

    #expect(measurement.topInset == 12)
    #expect(measurement.contentHeight == 200)
  }
}
