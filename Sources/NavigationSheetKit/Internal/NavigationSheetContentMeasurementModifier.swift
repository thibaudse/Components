#if os(iOS)
import SwiftUI

/// Measures one screen and reports how tall the sheet should be for it.
///
/// Two sources can answer, and which one is right depends on the screen. Fixed content has a
/// height; a scroll view has a content size and content insets, and its *frame* height is
/// whatever the sheet currently is — useless for deciding what the sheet should become. So
/// both are observed, and scroll geometry wins once it has produced a usable reading.
///
/// This sits above ``NavigationSheetBehindEffect`` in the chain deliberately: measurements
/// must reflect the screen's natural size, not the offset and opacity applied to hide it
/// while it is in the background.
struct NavigationSheetContentMeasurementModifier: ViewModifier {
  /// The three numbers, captured together.
  ///
  /// Taken as one value rather than three pieces of state so a detent is never computed from
  /// a top inset that arrived with this frame and a bottom inset left over from the last.
  private struct Snapshot: Equatable {
    enum Origin {
      case geometry
      case scrollGeometry
    }

    let topInset: CGFloat
    let contentHeight: CGFloat
    let bottomInset: CGFloat
    let origin: Origin
  }

  let pathDepth: Int

  @Environment(\.navigationSheetContainerInsets) private var containerInsets

  @State private var snapshot: Snapshot?

  func body(content: Content) -> some View {
    content
      .onGeometryChange(for: Snapshot.self) { proxy in
        Snapshot(
          topInset: max(0, proxy.safeAreaInsets.top),
          contentHeight: max(0, proxy.size.height),
          bottomInset: 0,
          origin: .geometry
        )
      } action: { _, newSnapshot in
        switch snapshot?.origin {
          case .geometry, .none:
            guard snapshot != newSnapshot else { return }
            snapshot = newSnapshot

          case .scrollGeometry:
            // Scroll geometry has already spoken for this screen; plain geometry would only
            // report the frame the sheet gave it, which is the answer we are trying to find.
            break
        }
      }
      .onScrollGeometryChange(for: Snapshot.self) { scrollGeometry in
        Snapshot(
          topInset: max(0, scrollGeometry.contentInsets.top),
          contentHeight: max(0, scrollGeometry.contentSize.height),
          bottomInset: max(0, scrollGeometry.contentInsets.bottom),
          origin: .scrollGeometry
        )
      } action: { _, newSnapshot in
        guard let snapshot, snapshot.topInset > 0, newSnapshot.topInset >= snapshot.topInset else { return }
        // The device's own bottom inset is already accounted for by the presentation, so
        // counting a scroll view's version of it again would make every scrollable screen
        // taller than it is.
        let scrollBottom = max(0, newSnapshot.bottomInset - containerInsets.bottom)
        // A high-water mark, because the detent changes the scroll view's insets, which
        // would otherwise change the detent: the two oscillate forever without it.
        let stableBottom = max(scrollBottom, snapshot.bottomInset)
        self.snapshot = Snapshot(
          topInset: newSnapshot.topInset,
          contentHeight: newSnapshot.contentHeight,
          bottomInset: stableBottom,
          origin: .scrollGeometry
        )
      }
      .preference(
        key: NavigationSheetContentMeasurementKey.self,
        value: [snapshot].compactMap { snapshot in
          snapshot.map {
            NavigationSheetContentMeasurement(
              pathDepth: pathDepth,
              topInset: $0.topInset,
              contentHeight: $0.contentHeight,
              bottomInset: $0.bottomInset
            )
          }
        }
      )
  }
}
#endif
