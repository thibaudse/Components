#if os(iOS)
import SwiftUI

// The modifiers a screen applies to itself. Each one reads its own depth from the environment
// and emits a preference against it, so the sheet can tell which screen asked for what.

/// Registers a destination builder with the nearest registry.
struct NavigationSheetDestinationRegistrar<Value: Hashable & Sendable, Destination: View>: ViewModifier {
  @Environment(\.navigationSheetRegistry) private var registry

  let valueType: Value.Type
  let destination: (Value) -> Destination

  func body(content: Content) -> some View {
    content
      // Keyed on the registry appearing rather than on every update: registration is
      // idempotent, but doing it during each body pass would churn an observable object the
      // sheet reads from.
      .onChange(of: registry != nil, initial: true) { _, _ in
        registry?.register(valueType) { destination($0) }
      }
  }
}

/// Asks for a specific detent for this screen.
struct NavigationSheetDetentModifier: ViewModifier {
  @Environment(\.navigationSheetPathDepth) private var pathDepth

  let preferredDetent: NavigationSheetPreferredDetent

  func body(content: Content) -> some View {
    content.preference(
      key: NavigationSheetDetentKey.self,
      value: [NavigationSheetDetentPreferenceItem(pathDepth: pathDepth, detent: preferredDetent)]
    )
  }
}

/// Hides the bar for this screen.
struct NavigationSheetToolbarVisibilityModifier: ViewModifier {
  @Environment(\.navigationSheetPathDepth) private var pathDepth

  let visibility: NavigationSheetToolbarVisibility

  func body(content: Content) -> some View {
    switch visibility {
      case .visible:
        content

      case .hidden:
        content.preference(key: NavigationSheetToolbarHiddenKey.self, value: [pathDepth])
    }
  }
}

/// Replaces or removes the navigation button for this screen.
///
/// A `nil` override emits nothing at all, which is how the built-in button comes back: the bar
/// falls back to its default for any depth that has not spoken.
struct NavigationSheetNavigationButtonModifier: ViewModifier {
  @Environment(\.navigationSheetPathDepth) private var pathDepth

  let override: NavigationSheetNavigationButtonOverride?

  func body(content: Content) -> some View {
    content.preference(
      key: NavigationSheetNavigationButtonKey.self,
      value: override.map { [NavigationSheetNavigationButtonItem(pathDepth: pathDepth, override: $0)] } ?? []
    )
  }
}

/// Adds an overlay behind this screen but in front of the sheet's background.
struct NavigationSheetBackgroundOverlayModifier<Overlay: View>: ViewModifier {
  @Environment(\.navigationSheetPathDepth) private var pathDepth

  let overlay: Overlay

  func body(content: Content) -> some View {
    content.preference(
      key: NavigationSheetBackgroundOverlayKey.self,
      value: [
        NavigationSheetBackgroundOverlayItem(
          pathDepth: pathDepth,
          content: AnyView(overlay)
        )
      ]
    )
  }
}
#endif
