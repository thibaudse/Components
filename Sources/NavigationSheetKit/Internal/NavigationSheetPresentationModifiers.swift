#if os(iOS)
import SwiftUI

// Two presenting modifiers, because `.sheet(isPresented:)` and `.sheet(item:)` differ in one
// way that matters: the item variant guarantees the value is there when the content is first
// built, so a sheet keyed on an optional never has to unwrap it again inside.
//
// Both create the destination registry and hand it to the container, and both capture the
// replaced chrome from the environment at the presenting view — the presenting view is where
// a caller sets it, and reading it here means the container does not depend on the
// environment surviving the trip into `.sheet`.

/// Presents a navigation sheet from a boolean binding.
struct NavigationSheetModifier<Root: View, SheetTransition: Transition>: ViewModifier {
  private let transition: SheetTransition?
  private let root: () -> Root

  @Binding private var isPresented: Bool
  @Binding private var path: NavigationSheetPath

  @Environment(\.navigationSheetChrome) private var chrome

  @State private var destinationRegistry = NavigationSheetDestinationRegistry()

  init(
    isPresented: Binding<Bool>,
    path: Binding<NavigationSheetPath>,
    @ViewBuilder root: @escaping () -> Root
  ) where SheetTransition == NavigationSheetPushPopTransition {
    self._isPresented = isPresented
    self._path = path
    self.transition = nil
    self.root = root
  }

  init(
    isPresented: Binding<Bool>,
    path: Binding<NavigationSheetPath>,
    transition: SheetTransition,
    @ViewBuilder root: @escaping () -> Root
  ) {
    self._isPresented = isPresented
    self._path = path
    self.transition = transition
    self.root = root
  }

  func body(content: Content) -> some View {
    content
      // Also injected outside the sheet, so `.navigationSheetDestination` can be declared at
      // the presenting call site as well as on the root content.
      .environment(\.navigationSheetRegistry, destinationRegistry)
      .sheet(isPresented: $isPresented, onDismiss: {
        path.removeAll()
      }) {
        NavigationSheetContainerView(
          transition: transition,
          root: root,
          dismissSheet: { isPresented = false },
          destinationRegistry: destinationRegistry,
          chrome: chrome,
          path: $path
        )
      }
  }
}

/// Presents a navigation sheet from an optional identifiable item.
struct NavigationSheetItemModifier<Item: Identifiable, Root: View, SheetTransition: Transition>: ViewModifier {
  private let transition: SheetTransition?
  private let root: (Item) -> Root

  @Binding private var item: Item?
  @Binding private var path: NavigationSheetPath

  @Environment(\.navigationSheetChrome) private var chrome

  @State private var destinationRegistry = NavigationSheetDestinationRegistry()

  init(
    item: Binding<Item?>,
    path: Binding<NavigationSheetPath>,
    @ViewBuilder root: @escaping (Item) -> Root
  ) where SheetTransition == NavigationSheetPushPopTransition {
    self._item = item
    self._path = path
    self.transition = nil
    self.root = root
  }

  init(
    item: Binding<Item?>,
    path: Binding<NavigationSheetPath>,
    transition: SheetTransition,
    @ViewBuilder root: @escaping (Item) -> Root
  ) {
    self._item = item
    self._path = path
    self.transition = transition
    self.root = root
  }

  func body(content: Content) -> some View {
    content
      .environment(\.navigationSheetRegistry, destinationRegistry)
      .sheet(item: $item, onDismiss: {
        path.removeAll()
      }) { value in
        NavigationSheetContainerView(
          transition: transition,
          root: { root(value) },
          dismissSheet: { item = nil },
          destinationRegistry: destinationRegistry,
          chrome: chrome,
          path: $path
        )
      }
  }
}
#endif
