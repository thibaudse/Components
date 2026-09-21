#if os(iOS)
import SwiftUI

/// The three pieces of sheet-wide appearance a caller can replace.
///
/// These travel in the environment rather than as preferences, because they belong to the
/// whole presentation rather than to one screen, and because the presenting view is the
/// natural place to set them. Each is `nil` until replaced, and `nil` means "use the
/// default" — which for the sheet background means the system's, untouched.
struct NavigationSheetChrome {
  var background: AnyView?
  var barBackground: AnyView?
  var dragIndicator: AnyView?
}

// MARK: - Defaults

/// The default drag indicator: a soft capsule, sized to leave the bar's height unchanged.
struct NavigationSheetDefaultDragIndicator: View {
  var body: some View {
    Capsule()
      .fill(.tertiary)
      .frame(width: 60, height: NavigationSheetMetrics.dragIndicatorHeight)
  }
}

/// The default bar background below iOS 26: a material that fades out downward.
///
/// On iOS 26 `safeAreaBar` gives the bar a progressive blur for free. Below that we
/// approximate it — a masked `.ultraThinMaterial` is not the same effect as a real variable
/// blur, but it reads the same way: solid where the title sits, gone by the time content
/// scrolls past.
struct NavigationSheetDefaultBarBackground: View {
  var body: some View {
    Rectangle()
      .fill(.ultraThinMaterial)
      .mask {
        LinearGradient(
          stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: 0.55),
            .init(color: .black.opacity(0.55), location: 0.82),
            .init(color: .clear, location: 1)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      }
      .ignoresSafeArea()
  }
}

// MARK: - Background

/// Publishes a replaced sheet background on both channels, because either end of the
/// presentation may declare it.
///
/// The environment reaches the **presenter**, which snapshots the chrome from its own
/// position in the tree — the only thing a presenting view can set. A preference travels
/// **outward** to the screen's host, which is the only direction that reaches the container
/// from inside the sheet. Whichever end declared it, exactly one of the two is ever read.
private struct NavigationSheetBackgroundModifier: ViewModifier {
  @Environment(\.navigationSheetPathDepth) private var pathDepth

  let background: AnyView

  func body(content: Content) -> some View {
    content
      .transformEnvironment(\.navigationSheetChrome) { $0.background = background }
      .preference(
        key: NavigationSheetBackgroundKey.self,
        value: [NavigationSheetBackgroundItem(pathDepth: pathDepth, content: background)]
      )
  }
}

// MARK: - Public API

public extension View {
  /// Replaces the sheet's presentation background.
  ///
  /// Left alone, the sheet keeps the system's background. Pass content here to draw your
  /// own — read `\.navigationSheetIsLargeDetent` inside it to distinguish a full-height
  /// sheet from a short one, and the change will crossfade as the detent moves.
  ///
  /// This is the one chrome piece that works from **either side**: set it on the presenting
  /// view for every screen the sheet shows, or inside a screen for that screen alone, where
  /// it wins over the presenting view's. A screen that paints its own panel is making the
  /// more specific statement, and it is the screen — not its host — that knows it.
  ///
  /// ```swift
  /// .navigationSheetBackground {
  ///   Color.black.opacity(0.95)
  /// }
  /// ```
  func navigationSheetBackground<Background: View>(
    @ViewBuilder _ content: () -> Background
  ) -> some View {
    modifier(NavigationSheetBackgroundModifier(background: AnyView(content())))
  }

  /// Replaces the sheet's presentation background with a style.
  ///
  /// `.navigationSheetBackground(.thinMaterial)` rather than a `Rectangle` filled with one.
  /// Styles that resolve against the environment — a design system's semantic color, say —
  /// resolve against the caller's, since the sheet re-injects it.
  func navigationSheetBackground(_ style: some ShapeStyle) -> some View {
    navigationSheetBackground { Rectangle().fill(style) }
  }

  /// Replaces the background behind the sheet's top bar.
  ///
  /// Left alone, the bar uses `safeAreaBar`'s own treatment on iOS 26 and later, and a
  /// downward-fading material below that.
  func navigationSheetBarBackground<Background: View>(
    @ViewBuilder _ content: () -> Background
  ) -> some View {
    let background = AnyView(content())
    return transformEnvironment(\.navigationSheetChrome) { $0.barBackground = background }
  }

  /// Replaces the sheet's drag indicator.
  ///
  /// Pass `EmptyView()` to remove it. Whatever you return is laid out at the top of the bar
  /// and does not change the bar's height, so tall content will overlap the toolbar.
  func navigationSheetDragIndicator<Indicator: View>(
    @ViewBuilder _ content: () -> Indicator
  ) -> some View {
    let indicator = AnyView(content())
    return transformEnvironment(\.navigationSheetChrome) { $0.dragIndicator = indicator }
  }
}
#endif
