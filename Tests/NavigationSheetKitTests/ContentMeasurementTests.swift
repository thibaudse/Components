import Testing

@testable import NavigationSheetKit

/// The arithmetic that decides how tall the sheet gets.
///
/// It is three numbers added together, which is exactly why it is worth pinning down: the
/// numbers arrive from two different sources — a geometry proxy or a scroll view's content
/// insets — and the sheet has no way to tell a wrong sum from a short screen.
@Suite("Content measurement")
struct ContentMeasurementTests {
  @Test("The detent height is the three parts added up")
  func sumsItsParts() {
    let measurement = NavigationSheetContentMeasurement(
      pathDepth: 0,
      topInset: 84,
      contentHeight: 332,
      bottomInset: 44
    )

    #expect(measurement.detentHeight == 460)
  }

  @Test("Content with no insets is its own height")
  func contentWithoutInsets() {
    let measurement = NavigationSheetContentMeasurement(
      pathDepth: 1,
      topInset: 0,
      contentHeight: 240,
      bottomInset: 0
    )

    #expect(measurement.detentHeight == 240)
  }

  // A screen reports zero before its geometry resolves, and the sheet keys off that to decide
  // it has not heard back yet. It has to stay exactly zero.
  @Test("An unmeasured screen reports zero")
  func unmeasuredScreenIsZero() {
    let measurement = NavigationSheetContentMeasurement(
      pathDepth: 0,
      topInset: 0,
      contentHeight: 0,
      bottomInset: 0
    )

    #expect(measurement.detentHeight == 0)
  }

  // Scroll geometry can hand back a negative bottom inset once the device's own inset has been
  // subtracted from it. A detent is a height; a negative one would resolve to something
  // nonsensical rather than failing loudly.
  @Test("Negative parts are floored rather than subtracted")
  func negativePartsAreFloored() {
    let measurement = NavigationSheetContentMeasurement(
      pathDepth: 2,
      topInset: 84,
      contentHeight: 200,
      bottomInset: -34
    )

    #expect(measurement.detentHeight == 284)
  }

  @Test("A wholly negative measurement is zero, not negative")
  func allNegativeIsZero() {
    let measurement = NavigationSheetContentMeasurement(
      pathDepth: 0,
      topInset: -10,
      contentHeight: -20,
      bottomInset: -30
    )

    #expect(measurement.detentHeight == 0)
  }

  @Test("Fractional heights survive the sum")
  func fractionalHeights() {
    let measurement = NavigationSheetContentMeasurement(
      pathDepth: 0,
      topInset: 47.5,
      contentHeight: 100.25,
      bottomInset: 0.25
    )

    #expect(measurement.detentHeight == 148)
  }

  @Test("Depth is carried through untouched")
  func depthIsPreserved() {
    let measurement = NavigationSheetContentMeasurement(
      pathDepth: 3,
      topInset: 0,
      contentHeight: 10,
      bottomInset: 0
    )

    #expect(measurement.pathDepth == 3)
  }

  // The sheet stores measurements in a dictionary keyed by depth and compares them to avoid
  // redundant detent changes, so two readings of the same screen must compare equal.
  @Test("Identical measurements are equal; a changed part is not")
  func equality() {
    let measurement = NavigationSheetContentMeasurement(pathDepth: 1, topInset: 84, contentHeight: 200, bottomInset: 0)
    let same = NavigationSheetContentMeasurement(pathDepth: 1, topInset: 84, contentHeight: 200, bottomInset: 0)
    let taller = NavigationSheetContentMeasurement(pathDepth: 1, topInset: 84, contentHeight: 201, bottomInset: 0)
    let deeper = NavigationSheetContentMeasurement(pathDepth: 2, topInset: 84, contentHeight: 200, bottomInset: 0)

    #expect(measurement == same)
    #expect(measurement != taller)
    #expect(measurement != deeper)
  }
}
