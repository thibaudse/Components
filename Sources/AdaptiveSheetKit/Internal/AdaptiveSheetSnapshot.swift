import CoreGraphics

/// The measuring modifier's one reading of the content, taken whole, and how each new reading changes it.
///
/// Whole, so a detent is never summed from a top inset that arrived with this frame and a bottom inset
/// left over from the last. The rules live here rather than in the modifier's `@State` because they are
/// about the *order* readings arrive in — plain geometry and scroll geometry report separately, and
/// either can come first — which is what `AdaptiveSheetSnapshotTests` pins without a hierarchy.
struct AdaptiveSheetSnapshot: Equatable {
  /// Where the current measurement came from.
  enum Origin: Equatable {
    case geometry
    case scrollGeometry
  }

  /// One plain-geometry reading: the content's laid-out frame and the sheet's bottom safe area.
  struct Layout: Equatable {
    let measurement: AdaptiveSheetMeasurement
    /// The home indicator's inset — or the keyboard's, while it is up — which the presentation
    /// already reserves below any detent.
    let containerBottomInset: CGFloat
  }

  private(set) var measurement: AdaptiveSheetMeasurement
  private(set) var containerBottomInset: CGFloat
  private(set) var origin: Origin
  /// The scroll view's reading as reported, before the container's inset came off — kept so the
  /// settled measurement can be recomputed when that inset changes. `nil` for plain geometry.
  private var rawScrollReading: AdaptiveSheetMeasurement?
  /// Whether `measurement` was recomputed for a new container inset from a scroll reading taken under
  /// the old one, so the next scroll reading must not hold the high-water mark over it.
  private var isRecomputedForContainer = false

  /// Starts from the content's first plain-geometry reading.
  init(layout: Layout) {
    measurement = layout.measurement
    containerBottomInset = layout.containerBottomInset
    origin = .geometry
  }

  /// Takes a plain-geometry reading.
  ///
  /// Until scroll geometry has spoken it replaces the measurement outright. After, the frame is only
  /// the one the sheet gave the content, and only the container's inset still counts: the home
  /// indicator can arrive a pass after the first scroll reading, and a keyboard comes and goes.
  mutating func take(_ layout: Layout) {
    switch origin {
    case .geometry:
      self = AdaptiveSheetSnapshot(layout: layout)
    case .scrollGeometry:
      guard layout.containerBottomInset != containerBottomInset, let raw = rawScrollReading else { return }

      // The raw reading still carries the old container's inset. When the new one is larger — the
      // late home indicator, a keyboard arriving — taking it off is right. When it is smaller — a
      // keyboard leaving ahead of its scroll reading — it would leave the keyboard's height behind
      // as content inset, so a new container inset may lower the bottom inset but never raise it.
      let recomputed = AdaptiveSheetMeasurement(
        scrollReading: raw,
        containerBottomInset: layout.containerBottomInset,
        previous: nil
      )
      measurement = AdaptiveSheetMeasurement(
        topInset: recomputed.topInset,
        contentHeight: recomputed.contentHeight,
        bottomInset: min(recomputed.bottomInset, measurement.bottomInset)
      )
      containerBottomInset = layout.containerBottomInset
      isRecomputedForContainer = true
    }
  }

  /// Takes a scroll view's reading — its content insets and content size, as reported.
  ///
  /// The bottom inset holds a high-water mark over the last scroll measurement, because the detent
  /// changes the scroll view's insets. A new container inset is not that detent-driven churn, so the
  /// first reading after one starts the mark again.
  mutating func take(scrollReading reading: AdaptiveSheetMeasurement) {
    // Plain geometry's bottom inset is a placeholder zero, not a reading to hold a mark over.
    let previous: AdaptiveSheetMeasurement? = switch origin {
    case .geometry: nil
    case .scrollGeometry: isRecomputedForContainer ? nil : measurement
    }

    measurement = AdaptiveSheetMeasurement(
      scrollReading: reading,
      containerBottomInset: containerBottomInset,
      previous: previous
    )
    origin = .scrollGeometry
    rawScrollReading = reading
    isRecomputedForContainer = false
  }
}
