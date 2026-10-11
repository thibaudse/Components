/// One SwiftUI measurement of an adaptive sheet's content, and where it was read from.
struct AdaptiveSheetReading: Equatable {
  /// Where a reading was taken.
  enum Source: Equatable {
    /// The content's laid-out frame. It can be the frame the sheet gave rather than the content's own
    /// height: a `NavigationStack` fills whatever it is offered.
    case layout
    /// A scroll view's content size and insets — always the content's own height.
    case scrollGeometry
  }

  let measurement: AdaptiveSheetMeasurement
  let source: Source
}
