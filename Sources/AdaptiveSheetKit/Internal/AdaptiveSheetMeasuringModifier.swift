#if os(iOS)
import SwiftUI

/// Measures an adaptive sheet's content and publishes it as ``AdaptiveSheetMeasurementKey``.
///
/// Two sources can answer, and which is right depends on the content. Static content has a height; a
/// scroll view has a content size and content insets, and its *frame* is whatever the sheet currently
/// is — useless for deciding what the sheet should become. So both are observed, and scroll geometry
/// wins once it has spoken.
struct AdaptiveSheetMeasuringModifier: ViewModifier {
  @State private var snapshot: AdaptiveSheetSnapshot?

  func body(content: Content) -> some View {
    content
      .onGeometryChange(for: AdaptiveSheetSnapshot.Layout.self) { proxy in
        AdaptiveSheetSnapshot.Layout(
          measurement: AdaptiveSheetMeasurement(
            topInset: max(0, proxy.safeAreaInsets.top),
            contentHeight: max(0, proxy.size.height),
            bottomInset: 0
          ),
          containerBottomInset: max(0, proxy.safeAreaInsets.bottom)
        )
      } action: { layout in
        switch snapshot {
        case .some: snapshot?.take(layout)
        case .none: snapshot = AdaptiveSheetSnapshot(layout: layout)
        }
      }
      .onScrollGeometryChange(for: AdaptiveSheetMeasurement.self) { geometry in
        AdaptiveSheetMeasurement(
          topInset: max(0, geometry.contentInsets.top),
          contentHeight: max(0, geometry.contentSize.height),
          bottomInset: max(0, geometry.contentInsets.bottom)
        )
      } action: { _, reading in
        // Waits for plain geometry to have reported the home indicator's inset: taken without
        // it, the first bottom inset would count the indicator, and the high-water mark would
        // keep that forever.
        snapshot?.take(scrollReading: reading)
      }
      .preference(key: AdaptiveSheetMeasurementKey.self, value: snapshot.map(Self.reading))
  }

  private static func reading(of snapshot: AdaptiveSheetSnapshot) -> AdaptiveSheetReading {
    let source: AdaptiveSheetReading.Source = switch snapshot.origin {
    case .geometry: .layout
    case .scrollGeometry: .scrollGeometry
    }
    return AdaptiveSheetReading(measurement: snapshot.measurement, source: source)
  }
}
#endif
