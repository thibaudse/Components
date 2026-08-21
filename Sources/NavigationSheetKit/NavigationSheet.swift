#if os(iOS)
import SwiftUI

// MARK: - Presentation

public extension View {
  /// Presents a sheet that can navigate within itself.
  ///
  /// This is what you reach for instead of putting a `NavigationStack` inside a `.sheet`. The
  /// sheet owns its own path, pushes and pops with a slide, keeps every screen's state alive
  /// while it is in the background, and resizes itself to whatever screen is showing.
  ///
  /// ```swift
  /// @State private var isPresented = false
  /// @State private var path = NavigationSheetPath()
  ///
  /// var body: some View {
  ///   Button("Settings") { isPresented = true }
  ///     .navigationSheet(isPresented: $isPresented, path: $path) {
  ///       SettingsRoot()
  ///         .navigationSheetTitle("Settings")
  ///         .navigationSheetDestination(for: SettingsRoute.self) { route in
  ///           SettingsDetail(route: route)
  ///         }
  ///     }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - isPresented: Whether the sheet is showing. It is emptied of its path on dismissal.
  ///   - path: The sheet's navigation path. Omit it for a sheet that never pushes anything.
  ///   - root: The sheet's first screen.
  func navigationSheet(
    isPresented: Binding<Bool>,
    path: Binding<NavigationSheetPath> = .constant(NavigationSheetPath()),
    @ViewBuilder root: @escaping () -> some View
  ) -> some View {
    modifier(NavigationSheetModifier(
      isPresented: isPresented,
      path: path,
      root: root
    ))
  }

  /// Presents a navigation sheet that pushes and pops with a transition of your choosing.
  ///
  /// The transition replaces the default slide for every screen the path pushes. It is applied
  /// to the arriving and departing screen, so an asymmetric transition reads as push and pop.
  func navigationSheet(
    isPresented: Binding<Bool>,
    path: Binding<NavigationSheetPath> = .constant(NavigationSheetPath()),
    transition: some Transition,
    @ViewBuilder root: @escaping () -> some View
  ) -> some View {
    modifier(NavigationSheetModifier(
      isPresented: isPresented,
      path: path,
      transition: transition,
      root: root
    ))
  }

  /// Presents a navigation sheet for an optional item.
  ///
  /// Prefer this over the boolean when the sheet's content depends on a value: the item is
  /// guaranteed non-nil when the root is first built, so there is nothing to unwrap inside and
  /// no window in which the sheet exists without its subject.
  func navigationSheet<Item: Identifiable>(
    item: Binding<Item?>,
    path: Binding<NavigationSheetPath> = .constant(NavigationSheetPath()),
    @ViewBuilder root: @escaping (Item) -> some View
  ) -> some View {
    modifier(NavigationSheetItemModifier(
      item: item,
      path: path,
      root: root
    ))
  }

  /// Presents a navigation sheet for an optional item, with a transition of your choosing.
  func navigationSheet<Item: Identifiable>(
    item: Binding<Item?>,
    path: Binding<NavigationSheetPath> = .constant(NavigationSheetPath()),
    transition: some Transition,
    @ViewBuilder root: @escaping (Item) -> some View
  ) -> some View {
    modifier(NavigationSheetItemModifier(
      item: item,
      path: path,
      transition: transition,
      root: root
    ))
  }

  /// Registers the view to show for a path value's type.
  ///
  /// The counterpart to `navigationDestination(for:destination:)`. Declare it on the sheet's
  /// root content — or at the presenting call site, either reaches the sheet — once per value
  /// type the path can hold. Pushing a value whose type was never registered does nothing and
  /// reports a fault to the `NavigationSheetKit` subsystem.
  func navigationSheetDestination<Value: Hashable & Sendable>(
    for valueType: Value.Type,
    @ViewBuilder destination: @escaping (Value) -> some View
  ) -> some View {
    modifier(NavigationSheetDestinationRegistrar(valueType: valueType, destination: destination))
  }
}

// MARK: - Bar

public extension View {
  /// Sets this screen's title.
  ///
  /// Shorthand for a `.title`-placed toolbar item at `.headline`. For a title that is not a
  /// line of text — a segmented control, a subtitle stacked under a name — declare the item
  /// yourself with `navigationSheetToolbar { }` and a `.title` placement.
  func navigationSheetTitle(_ text: Text) -> some View {
    navigationSheetToolbar {
      NavigationSheetToolbarItem(placement: .title) {
        text.font(.headline)
      }
    }
  }

  /// Sets this screen's title from a string.
  func navigationSheetTitle(_ text: String) -> some View {
    navigationSheetTitle(Text(verbatim: text))
  }

  /// Declares this screen's toolbar items.
  ///
  /// Compose ``NavigationSheetToolbarItem`` values inside, the way you would inside SwiftUI's
  /// `.toolbar`. Items belong to the screen that declares them and vanish with it.
  func navigationSheetToolbar(@ViewBuilder _ content: () -> some View) -> some View {
    background { content() }
  }

  /// Hides or shows the bar for this screen.
  ///
  /// Hiding it collapses the bar to just the drag indicator, and the screen gets the height
  /// back. Nothing else changes — the sheet still measures and sizes the same way.
  func navigationSheetToolbar(_ visibility: NavigationSheetToolbarVisibility) -> some View {
    modifier(NavigationSheetToolbarVisibilityModifier(visibility: visibility))
  }

  /// Turns off the automatic button styling for this screen's toolbar items.
  ///
  /// Toolbar buttons are styled for you by default — `.bordered`, becoming `.glass` at the
  /// large detent on iOS 26 and later. Pass `.hidden` when you want to style them yourself.
  func navigationSheetToolbarButtonStyle(_ style: NavigationSheetToolbarButtonStyle) -> some View {
    environment(\.navigationSheetToolbarButtonStyle, style)
  }

  /// Replaces this screen's navigation button — the leading button that closes the sheet at
  /// the root and goes back once something has been pushed.
  ///
  /// Call `\.navigationSheetDismiss` from inside to keep that behaviour with different
  /// content, or do something else entirely. Read `\.navigationSheetPathDepth` if the same
  /// screen appears at more than one depth and the button should differ.
  ///
  /// ```swift
  /// .navigationSheetNavigationButton {
  ///   Button("Done") { dismiss() }
  /// }
  /// ```
  func navigationSheetNavigationButton(
    @ViewBuilder _ content: () -> some View
  ) -> some View {
    modifier(NavigationSheetNavigationButtonModifier(override: .custom(AnyView(content()))))
  }

  /// Hides or shows this screen's navigation button.
  ///
  /// Hiding it leaves the bar in place with nothing in its leading slot — for a screen the
  /// user must not leave by tapping past it, or one whose leading toolbar item does the job.
  /// `.visible` restores the built-in button.
  func navigationSheetNavigationButton(_ visibility: NavigationSheetToolbarVisibility) -> some View {
    modifier(NavigationSheetNavigationButtonModifier(
      override: visibility == .hidden ? .hidden : nil
    ))
  }
}

// MARK: - Sizing

public extension View {
  /// Overrides the detent for this screen.
  ///
  /// The sheet measures each screen and sizes itself to fit, capped at large. Use this when
  /// the measurement is not what you want: `.detent(.large)` for a screen that should fill the
  /// sheet whatever its content, `.detent(.height(320))` for a fixed one.
  func navigationSheetDetent(_ detent: NavigationSheetPreferredDetent) -> some View {
    modifier(NavigationSheetDetentModifier(preferredDetent: detent))
  }
}

// MARK: - Background

public extension View {
  /// Adds an overlay to this screen, drawn on top of the sheet's background and behind the
  /// screen's own content.
  ///
  /// For a gradient or an image that belongs to one screen rather than to the sheet. Moving
  /// between screens crossfades their overlays.
  func navigationSheetBackgroundOverlay(@ViewBuilder _ content: () -> some View) -> some View {
    modifier(NavigationSheetBackgroundOverlayModifier(overlay: content()))
  }
}
#endif
