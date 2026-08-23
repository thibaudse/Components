#if os(iOS)
import SwiftUI
import UIKit

/// The sheet's bar, hosted as one SwiftUI tree pinned to the top of the container.
///
/// UIKit owns where the bar sits and how tall it is; everything about how it looks — the
/// slots, the crossfades, the drag indicator, the replaced chrome — stays SwiftUI, because
/// that is the layer SwiftUI is good at and the port already solved.
final class NavigationSheetBarController: UIHostingController<NavigationSheetBarContent> {
  init(model: NavigationSheetModel) {
    super.init(rootView: NavigationSheetBarContent(model: model))
    view.backgroundColor = .clear
    // The bar is pinned top/leading/trailing with no height constraint — its SwiftUI
    // content's intrinsic size is what gives Auto Layout the height.
    sizingOptions = [.intrinsicContentSize]
  }

  @available(*, unavailable)
  @MainActor required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }
}

/// The bar itself: drag indicator, three slots, and the default navigation button.
struct NavigationSheetBarContent: View {
  let model: NavigationSheetModel

  var body: some View {
    ZStack(alignment: .top) {
      dragIndicator

      navigationBar
    }
    .frame(maxWidth: .infinity, alignment: .top)
    .background(alignment: .top) {
      if !model.isToolbarHidden {
        barBackground
      }
    }
    .animation(.smooth(duration: NavigationSheetMetrics.animationDuration), value: model.isToolbarHidden)
    .environment(\.navigationSheetIsLargeDetent, model.isLargeDetent)
    .environment(\.navigationSheetDismiss, model.dismissAction)
    // Outermost: the caller's environment is the base the keys above override.
    .environment(\.self, model.environment)
  }

  @ViewBuilder
  private var barBackground: some View {
    if let background = model.chrome.barBackground {
      background
    } else {
      NavigationSheetDefaultBarBackground()
        .frame(height: NavigationSheetMetrics.barHeight + 20)
    }
  }

  private var dragIndicator: some View {
    Group {
      if let indicator = model.chrome.dragIndicator {
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
    if !model.isToolbarHidden {
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

    /// Regular on iOS 26, where glass buttons carry their own presence; small below, where
    /// bordered buttons at regular read oversized in an 84pt bar.
    private var controlSize: ControlSize {
      if #available(iOS 26.0, *) {
        .regular
      } else {
        .small
      }
    }

    var body: some View {
      ZStack {
        content()
          .controlSize(controlSize)
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
    switch model.navigationButtonsByDepth[model.currentDepth] {
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
    if model.currentDepth == 0 {
      Button {
        model.dismissSheet()
      } label: {
        Image(systemName: "xmark")
          .imageScale(.medium)
      }
      .accessibilityLabel(Text(.navigationClose))
      .modifier(NavigationSheetToolbarButtonStyleModifier())
    } else {
      Button {
        model.pop()
      } label: {
        Image(systemName: "chevron.left")
          .imageScale(.medium)
      }
      .accessibilityLabel(Text(.navigationBack))
      .modifier(NavigationSheetToolbarButtonStyleModifier())
    }
  }

  // MARK: - Lookup

  private func toolbarItems(for placement: NavigationSheetToolbarPlacement) -> [NavigationSheetToolbarResolvedItem] {
    (model.toolbarItemsByDepth[model.currentDepth] ?? []).filter { $0.placement == placement }
  }

  /// The identity of a slot's contents, which is what the crossfade animates on.
  private func toolbarKey(
    for placement: NavigationSheetToolbarPlacement,
    items: [NavigationSheetToolbarResolvedItem]
  ) -> String {
    var components = ["depth", "\(model.currentDepth)"]

    if placement == .topBarLeading {
      let navigation: String = switch model.navigationButtonsByDepth[model.currentDepth] {
        case .hidden: "none"
        case .custom: "custom"
        case .none: model.currentDepth == 0 ? "dismiss" : "back"
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
}
#endif
