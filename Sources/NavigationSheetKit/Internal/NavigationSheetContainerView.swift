#if os(iOS)
import SwiftUI

/// The sheet itself: bar, detents, navigation, and the state that belongs to one presentation.
///
/// Both presenting modifiers — the boolean one and the item one — put this inside `.sheet`,
/// so everything a presentation owns lives here and is discarded with it.
///
/// The layout is inverted from what you might expect. The bar is the primary element and the
/// content is its `.background`, rather than the two being stacked. A `VStack` would let a
/// screen's height changes resize the bar mid-transition, which is visible and awful; this
/// way the bar is a fixed frame the content can never push around.
struct NavigationSheetContainerView<Root: View, SheetTransition: Transition>: View {
  /// A custom transition, or `nil` for the default push/pop slide.
  let transition: SheetTransition?
  /// The sheet's first screen.
  let root: () -> Root
  /// Dismisses the whole sheet.
  let dismissSheet: () -> Void
  /// Destination builders, shared with the presenting modifier.
  let destinationRegistry: NavigationSheetDestinationRegistry
  /// Appearance the caller replaced, captured at the presenting view.
  let chrome: NavigationSheetChrome

  @Binding var path: NavigationSheetPath

  /// Detents currently offered to the sheet. Usually one; two during a transition, so
  /// SwiftUI has something to interpolate between.
  @State private var detents: Set<PresentationDetent> = [.sheetLarge]
  /// The selected detent.
  @State private var currentDetent: PresentationDetent = .sheetLarge
  /// Toolbar items by depth. Cached per depth rather than read live, so a fast push does not
  /// briefly show the outgoing screen's buttons.
  @State private var toolbarItemsByDepth: [Int: [NavigationSheetToolbarResolvedItem]] = [:]
  /// Detents screens asked for explicitly.
  @State private var preferredDetentsByDepth: [Int: NavigationSheetPreferredDetent] = [:]
  /// Depths that hide the bar.
  @State private var toolbarHiddenDepths: Set<Int> = []
  /// Depths that replaced or removed the navigation button.
  @State private var navigationButtonsByDepth: [Int: NavigationSheetNavigationButtonOverride] = [:]
  /// Background overlays by depth.
  @State private var backgroundOverlaysByDepth: [Int: AnyView] = [:]
  /// What each screen reported about its height.
  @State private var measurementsByDepth: [Int: NavigationSheetContentMeasurement] = [:]
  /// The in-flight detent change: yield, select, wait out the animation, prune.
  @State private var detentTransitionTask: Task<Void, Never>?
  /// Which way the path last moved.
  @State private var directionTracker = NavigationSheetDirectionTracker()
  /// The device's safe area insets, read from the window.
  @State private var windowInsets = EdgeInsets()

  /// Whether the sheet currently fills the screen.
  private var isLargeDetent: Bool {
    currentDetent == .sheetLarge
  }

  var body: some View {
    sheetContainer
      .transform { view in
        if let background = chrome.background {
          view.presentationBackground {
            background
              .environment(\.navigationSheetIsLargeDetent, isLargeDetent)
              .animation(.smooth, value: currentDetent)
          }
        } else {
          view
        }
      }
      .environment(\.navigationSheetRegistry, destinationRegistry)
      .environment(\.navigationSheetDismiss, NavigationSheetDismissAction { behavior in
        Task { @MainActor in
          switch behavior {
            case .current:
              if path.isEmpty {
                dismissSheet()
              } else {
                path.removeLast()
              }

            case .all:
              dismissSheet()
          }
        }
      })
      .onAppear {
        applyDetentForCurrentDepth()
      }
      .onChange(of: path.count) { oldCount, newCount in
        // Drop any measurement left over from a previous visit to the depth being pushed, so
        // the sheet does not flash to that screen's old height before the new one reports.
        if newCount > oldCount {
          measurementsByDepth.removeValue(forKey: newCount)
        }
        applyDetentForCurrentDepth()
      }
      .presentationDetents(detents, selection: $currentDetent)
      // The bar draws its own indicator, so the system's would be a second one.
      .presentationDragIndicator(.hidden)
  }

  // MARK: - Container

  @ViewBuilder
  private var sheetContainer: some View {
    Color.clear
      .frame(height: isToolbarHidden ? NavigationSheetMetrics.collapsedBarHeight : NavigationSheetMetrics.barHeight)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(alignment: .top) {
        NavigationSheetBody(
          transition: transition,
          directionTracker: directionTracker,
          root: root,
          path: $path
        )
        .environment(\.navigationSheetPath, $path)
        .onPreferenceChange(NavigationSheetToolbarItemsKey.self, perform: updateToolbarItems)
        .onPreferenceChange(NavigationSheetDetentKey.self, perform: updatePreferredDetents)
        .onPreferenceChange(NavigationSheetContentMeasurementKey.self, perform: updateMeasurements)
        .onPreferenceChange(NavigationSheetToolbarHiddenKey.self) { toolbarHiddenDepths = Set($0) }
        .onPreferenceChange(NavigationSheetNavigationButtonKey.self, perform: updateNavigationButtons)
        .onPreferenceChange(NavigationSheetBackgroundOverlayKey.self) { items in
          backgroundOverlaysByDepth = Dictionary(
            items.map { ($0.pathDepth, $0.content) },
            uniquingKeysWith: { _, latest in latest }
          )
        }
        .navigationSheetBar(background: chrome.barBackground) {
          barContent
        }
      }
      .background {
        backgroundOverlayForCurrentDepth
      }
      .background {
        WindowSafeAreaReader { insets in
          guard insets != windowInsets else { return }
          windowInsets = insets
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
      }
      .environment(\.navigationSheetWindowInsets, windowInsets)
      .environment(\.navigationSheetIsLargeDetent, isLargeDetent)
  }

  // MARK: - Bar

  private var barContent: some View {
    ZStack(alignment: .top) {
      dragIndicator

      navigationBar
    }
    .animation(.smooth(duration: NavigationSheetMetrics.animationDuration), value: isToolbarHidden)
  }

  private var dragIndicator: some View {
    Group {
      if let indicator = chrome.dragIndicator {
        indicator
      } else {
        NavigationSheetDefaultDragIndicator()
      }
    }
    .padding(.vertical, NavigationSheetMetrics.dragIndicatorVerticalPadding)
  }

  /// The bar's three slots. Overlays rather than an `HStack`, so a long title centres on the
  /// bar instead of on the space the buttons leave over.
  @ViewBuilder
  private var navigationBar: some View {
    if !isToolbarHidden {
      Color.clear
        .frame(height: NavigationSheetMetrics.barHeight)
        .overlay(alignment: .leading) {
          toolbarLeadingView
        }
        .overlay(alignment: .center) {
          toolbarTitleView
        }
        .overlay(alignment: .trailing) {
          toolbarTrailingView
        }
        .transition(.blurReplace)
    }
  }

  /// Crossfades whatever is in one slot when its identity changes.
  private struct NavigationSheetToolbarSlot<SlotContent: View>: View {
    let key: String
    @ViewBuilder let content: () -> SlotContent

    @State private var areAnimationsEnabled = false

    var body: some View {
      ZStack {
        content()
          .transform { view in
            if #available(iOS 26.0, *) {
              view.controlSize(.regular)
            } else {
              view.controlSize(.small)
            }
          }
          .id(key)
          .transition(.blurReplace)
      }
      .animation(areAnimationsEnabled ? .smooth(duration: NavigationSheetMetrics.animationDuration) : nil, value: key)
      // Nothing should animate on the way in — the first key is not a change.
      .task {
        try? await Task.sleep(for: .seconds(NavigationSheetMetrics.animationDuration))
        areAnimationsEnabled = true
      }
    }
  }

  @ViewBuilder
  private var toolbarLeadingView: some View {
    let items = toolbarItems(for: .topBarLeading)
    NavigationSheetToolbarSlot(key: toolbarKey(for: .topBarLeading, items: items)) {
      HStack(spacing: 4) {
        navigationButton

        ForEach(items.indices, id: \.self) { index in
          items[index].content
        }
      }
      .padding(.leading, 16)
    }
  }

  @ViewBuilder
  private var toolbarTitleView: some View {
    let items = toolbarItems(for: .title)
    NavigationSheetToolbarSlot(key: toolbarKey(for: .title, items: items)) {
      if let title = items.first {
        title.content
      }
    }
  }

  @ViewBuilder
  private var toolbarTrailingView: some View {
    let items = toolbarItems(for: .topBarTrailing)
    NavigationSheetToolbarSlot(key: toolbarKey(for: .topBarTrailing, items: items)) {
      if !items.isEmpty {
        HStack(spacing: 12) {
          ForEach(items.indices, id: \.self) { index in
            items[index].content
          }
        }
        .padding(.trailing, 12)
      }
    }
  }

  // MARK: - Navigation Button

  @ViewBuilder
  private var navigationButton: some View {
    switch navigationButtonsByDepth[path.count] {
      case .hidden:
        EmptyView()

      case .custom(let content):
        content

      case .none:
        defaultNavigationButton
    }
  }

  /// Close at the root, back once something has been pushed.
  @ViewBuilder
  private var defaultNavigationButton: some View {
    if path.isEmpty {
      Button {
        dismissSheet()
      } label: {
        Image(systemName: "xmark")
          .imageScale(.medium)
      }
      .accessibilityLabel(Text(.navigationClose))
      .modifier(NavigationSheetToolbarButtonStyleModifier())
    } else {
      Button {
        path.removeLast()
      } label: {
        Image(systemName: "chevron.left")
          .imageScale(.medium)
      }
      .accessibilityLabel(Text(.navigationBack))
      .modifier(NavigationSheetToolbarButtonStyleModifier())
    }
  }

  // MARK: - Toolbar Lookup

  private func toolbarItems(for placement: NavigationSheetToolbarPlacement) -> [NavigationSheetToolbarResolvedItem] {
    (toolbarItemsByDepth[path.count] ?? []).filter { $0.placement == placement }
  }

  /// The identity of a slot's contents, which is what the crossfade animates on.
  private func toolbarKey(
    for placement: NavigationSheetToolbarPlacement,
    items: [NavigationSheetToolbarResolvedItem]
  ) -> String {
    var components = ["depth", "\(path.count)"]

    if placement == .topBarLeading {
      let navigation: String = switch navigationButtonsByDepth[path.count] {
        case .hidden: "none"
        case .custom: "custom"
        case .none: path.isEmpty ? "dismiss" : "back"
      }
      components.append("nav|\(navigation)")
    }

    if items.isEmpty {
      components.append("empty")
    } else {
      components.append("items|\(items.map(\.id).joined(separator: ","))")
    }

    return components.joined(separator: "|")
  }

  // MARK: - Preference Handling

  private func updateToolbarItems(_ newItems: [NavigationSheetToolbarResolvedItem]) {
    var grouped: [Int: [NavigationSheetToolbarResolvedItem]] = [:]
    for item in newItems {
      grouped[item.pathDepth, default: []].append(item)
    }
    // Replaced wholesale, so a depth that no longer contributes items is cleared rather than
    // keeping its last set forever.
    toolbarItemsByDepth = grouped
  }

  private func updateNavigationButtons(_ items: [NavigationSheetNavigationButtonItem]) {
    navigationButtonsByDepth = Dictionary(
      items.map { ($0.pathDepth, $0.override) },
      uniquingKeysWith: { _, latest in latest }
    )
  }

  private func updatePreferredDetents(_ items: [NavigationSheetDetentPreferenceItem]) {
    preferredDetentsByDepth = Dictionary(
      items.map { ($0.pathDepth, $0.detent) },
      uniquingKeysWith: { _, latest in latest }
    )
    applyDetentForCurrentDepth()
  }

  private func updateMeasurements(_ items: [NavigationSheetContentMeasurement]) {
    for item in items {
      // Views report zero before their geometry resolves; storing that would size the sheet
      // to nothing for a frame.
      if item.detentHeight > 0 {
        measurementsByDepth[item.pathDepth] = item
      }
    }
    applyDetentForCurrentDepth()
  }

  // MARK: - Detents

  private var isToolbarHidden: Bool {
    toolbarHiddenDepths.contains(path.count)
  }

  /// The detent this depth demanded, if it demanded one.
  private var currentForcedDetent: PresentationDetent? {
    switch preferredDetentsByDepth[path.count] {
      case .detent(let value):
        return value

      case .automatic, .none:
        return nil
    }
  }

  /// Picks the detent for the current depth: an explicit one if the screen asked, otherwise
  /// its measured height, capped at large. With neither, nothing happens — better to stay
  /// where we are than to guess and then correct.
  private func applyDetentForCurrentDepth() {
    if let forcedDetent = currentForcedDetent {
      applyDetent(forcedDetent)
      return
    }

    guard let measurement = measurementsByDepth[path.count] else { return }

    let detentHeight = measurement.detentHeight
    guard detentHeight > 0 else { return }

    let largeHeight = NavigationSheetLargeDetent.resolvedHeight
    if largeHeight > 0, detentHeight >= largeHeight {
      applyDetent(.sheetLarge)
    } else {
      applyDetent(.height(detentHeight))
    }
  }

  /// Moves the sheet to a new detent.
  ///
  /// SwiftUI will only animate between detents it has been offered, so both are added, the
  /// new one is selected a frame later, and the old one is pruned once the animation is done.
  /// Pruning matters: leaving them all in place would let a drag snap to any height the sheet
  /// has ever been.
  private func applyDetent(_ newDetent: PresentationDetent) {
    detentTransitionTask?.cancel()

    guard newDetent != currentDetent else {
      detentTransitionTask = nil
      detents = [newDetent]
      return
    }

    detents = [currentDetent, newDetent]
    detentTransitionTask = Task { @MainActor in
      await Task.yield()
      guard !Task.isCancelled else { return }
      currentDetent = newDetent
      try? await Task.sleep(for: .seconds(NavigationSheetMetrics.animationDuration))
      guard !Task.isCancelled else { return }
      detents = [newDetent]
    }
  }

  // MARK: - Background Overlay

  @ViewBuilder
  private var backgroundOverlayForCurrentDepth: some View {
    let depth = path.count
    if let overlay = backgroundOverlaysByDepth[depth] {
      overlay
        .id(depth)
        .transition(.opacity.animation(.smooth))
    }
  }
}
#endif
