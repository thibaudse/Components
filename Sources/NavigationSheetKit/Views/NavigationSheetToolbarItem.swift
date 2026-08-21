#if os(iOS)
import SwiftUI

/// An item in a navigation sheet's bar.
///
/// The shape mirrors SwiftUI's `ToolbarItem`: give it a placement and content, and compose
/// items inside `.navigationSheetToolbar { }`. Each item emits a preference, which is how it
/// reaches a bar that is drawn above it in the hierarchy.
///
/// ```swift
/// .navigationSheetToolbar {
///   NavigationSheetToolbarItem(placement: .title) {
///     Text("Details")
///   }
///   NavigationSheetToolbarItem(id: "save", placement: .topBarTrailing) {
///     Button("Save", action: save)
///   }
/// }
/// ```
///
/// Items belong to the screen that declares them and appear only while that screen is
/// showing, so a pushed destination replaces the bar's contents rather than adding to them.
public struct NavigationSheetToolbarItem<Content: View>: View {
  @Environment(\.navigationSheetPathDepth) private var pathDepth
  @Environment(\.navigationSheetToolbarButtonStyle) private var toolbarButtonStyle

  private let id: String?
  private let placement: NavigationSheetToolbarPlacement
  private let content: Content

  @State private var fallbackID = UUID().uuidString

  /// Creates a toolbar item at the given placement.
  ///
  /// - Parameters:
  ///   - id: A stable identifier. The bar animates between items whose identity changes, so
  ///     pass one when the same slot's content should crossfade — a play button becoming a
  ///     pause button, say. Without it, the item keeps one identity for its lifetime and
  ///     only depth changes animate.
  ///   - placement: Where the item sits in the bar.
  ///   - content: The item's content.
  public init(
    id: String? = nil,
    placement: NavigationSheetToolbarPlacement,
    @ViewBuilder content: () -> Content
  ) {
    self.id = id
    self.placement = placement
    self.content = content()
  }

  public var body: some View {
    // The item itself draws nothing: it is declared inside a background, and its whole job
    // is to hand its content up to the bar as a preference.
    Color.clear
      .frame(width: 0, height: 0)
      .preference(
        key: NavigationSheetToolbarItemsKey.self,
        value: [
          NavigationSheetToolbarResolvedItem(
            id: id ?? fallbackID,
            placement: placement,
            pathDepth: pathDepth,
            content: AnyView(resolvedContent)
          )
        ]
      )
  }

  @ViewBuilder
  private var resolvedContent: some View {
    switch toolbarButtonStyle {
      case .automatic:
        content.modifier(NavigationSheetToolbarButtonStyleModifier())

      case .hidden:
        content
    }
  }
}
#endif
