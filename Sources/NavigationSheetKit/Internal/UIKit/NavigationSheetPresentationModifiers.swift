#if os(iOS)
import SwiftUI

// The two presenting modifiers. Each owns the destination registry for its presentation and
// drops a zero-size presenter into the background of the presenting view — the UIKit anchor
// the sheet is presented from.

/// Presents a navigation sheet from a boolean binding.
struct NavigationSheetModifier<Root: View>: ViewModifier {
  @Binding var isPresented: Bool
  @Binding var path: NavigationSheetPath
  let root: () -> Root

  @State private var destinationRegistry = NavigationSheetDestinationRegistry()

  func body(content: Content) -> some View {
    content
      // Injected outside the sheet too, so `.navigationSheetDestination` can be declared at
      // the presenting call site as well as on the root content.
      .environment(\.navigationSheetRegistry, destinationRegistry)
      .background {
        NavigationSheetPresenter(
          isPresented: isPresented,
          path: $path,
          destinationRegistry: destinationRegistry,
          root: { AnyView(root()) },
          setDismissed: { isPresented = false }
        )
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
      }
  }
}

/// Presents a navigation sheet from an optional identifiable item.
///
/// The root builder reads the binding when the sheet is created, so the item is guaranteed
/// non-nil when the root is first built — the same contract as `.sheet(item:)`.
struct NavigationSheetItemModifier<Item: Identifiable, Root: View>: ViewModifier {
  @Binding var item: Item?
  @Binding var path: NavigationSheetPath
  let root: (Item) -> Root

  @State private var destinationRegistry = NavigationSheetDestinationRegistry()

  func body(content: Content) -> some View {
    content
      .environment(\.navigationSheetRegistry, destinationRegistry)
      .background {
        NavigationSheetPresenter(
          isPresented: item != nil,
          path: $path,
          destinationRegistry: destinationRegistry,
          root: { [item = $item] in
            if let value = item.wrappedValue {
              return AnyView(root(value))
            }
            // Unreachable while the presenting contract holds: the presenter only builds
            // the root when `isPresented` — here, `item != nil` — was true.
            NavigationSheetLog.fault("Navigation sheet item was nil when the root was built")
            return AnyView(EmptyView())
          },
          setDismissed: { item = nil }
        )
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
      }
  }
}
#endif
