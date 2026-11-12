#if os(iOS)
import SwiftUI

// MARK: - Presenting

/// How `sheet(isPresented:style:onDismiss:content:)` and `sheet(item:style:onDismiss:content:)`
/// present: SwiftUI's own overloads keep presenting a system sheet.
public enum SheetStyle: Sendable {
  /// The Apple Sports card: rests at its detent — floating below `.large` — and one drag takes it
  /// to full screen and on into the content, back down, and away.
  case card
}

@available(iOS 26.0, *)
extension View {
  /// Presents a sheet in `style` when `isPresented` is true — `sheet(isPresented:onDismiss:content:)`
  /// with a style.
  ///
  /// The content takes SwiftUI's own presentation modifiers: `presentationDetents` (the card rests
  /// at the smallest detent and can be dragged between them, then on to full screen),
  /// `presentationDragIndicator`, `presentationCornerRadius`, `presentationBackgroundInteraction`,
  /// `presentationContentInteraction` and `interactiveDismissDisabled`; and these, which a system
  /// sheet has no equivalent for: `presentationSnapping`, `presentationExpandsToFullScreen`,
  /// `presentationNeighbourPeek`.
  public func sheet<Content: View>(
    isPresented: Binding<Bool>,
    style: SheetStyle,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    sheet(isPresented: isPresented, onDismiss: onDismiss) {
      CardSheetRoot(
        pages: [SinglePage()], startIndex: 0,
        dismiss: { withoutAnimation { isPresented.wrappedValue = false } },
        pageChanged: { _ in },
        content: { _ in content() }
      )
    }
  }

  /// Presents a sheet in `style` for `item` while it is non-nil —
  /// `sheet(item:onDismiss:content:)` with a style.
  public func sheet<Item: Identifiable, Content: View>(
    item: Binding<Item?>,
    style: SheetStyle,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Item) -> Content
  ) -> some View {
    sheet(item: item, onDismiss: onDismiss) { presented in
      CardSheetRoot(
        pages: [presented], startIndex: 0,
        dismiss: { withoutAnimation { item.wrappedValue = nil } },
        pageChanged: { _ in },
        content: content
      )
    }
  }

  /// Presents `items` side by side, opened on `selection` while it is non-nil — the Apple Sports
  /// card: swipe sideways between them at any height but full screen, the neighbours peeking in
  /// the margins. `selection` follows the item on screen, and is set to nil on dismissal.
  public func sheet<Items: RandomAccessCollection, Content: View>(
    items: Items,
    selection: Binding<Items.Element.ID?>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Items.Element) -> Content
  ) -> some View where Items.Element: Identifiable {
    let pages = Array(items)
    let presented = Binding(
      get: { selection.wrappedValue != nil },
      set: { if !$0 { selection.wrappedValue = nil } }
    )
    return sheet(isPresented: presented, onDismiss: onDismiss) {
      CardSheetRoot(
        pages: pages,
        startIndex: pages.firstIndex { $0.id == selection.wrappedValue } ?? 0,
        dismiss: { withoutAnimation { selection.wrappedValue = nil } },
        pageChanged: { selection.wrappedValue = pages[$0].id },
        content: content
      )
    }
  }
}

// MARK: - Modifiers a system sheet has no equivalent for

/// Whether a card released between two resting places springs to one of them.
public enum PresentationSnapping: Equatable, Sendable {
  /// Snaps when the content declares more than one detent; otherwise the card stays wherever it
  /// is released.
  case automatic
  /// Always springs to the nearest detent, or to full screen.
  case always
  /// Stays wherever it is released.
  case never
}

@available(iOS 26.0, *)
extension View {
  /// How a card sheet released between resting places behaves. Default: `.automatic`.
  public func presentationSnapping(_ snapping: PresentationSnapping) -> some View {
    presentationOption(.init(snapping: snapping))
  }

  /// Whether a card sheet that can reach `.large` goes on past it to fill the whole display, over
  /// the status bar. A card whose detents stop short of `.large` never does. Default: true.
  public func presentationExpandsToFullScreen(_ expands: Bool = true) -> some View {
    presentationOption(.init(expandsToFullScreen: expands))
  }

  /// How much of each neighbouring card shows at rest, in points, when the sheet pages through
  /// several items. Default: 10.
  public func presentationNeighbourPeek(_ width: CGFloat) -> some View {
    presentationOption(.init(neighbourPeek: width))
  }

  /// Merged into what is already set rather than replacing it: `.preference` replaces its key's
  /// whole value for everything inside it, so a second of these modifiers would erase the first.
  private func presentationOption(_ option: CardSheetOptions) -> some View {
    transformPreference(CardSheetOptionsKey.self) { $0 = $0.merged(with: option) }
  }
}

// MARK: - Environment

extension EnvironmentValues {
  /// How far the card is towards full screen: 0 at its resting detent, 1 full screen. Content can
  /// use it to clear the status bar, or to show more as the card grows.
  @Entry public var presentationExpansion: CGFloat = 0
}
#endif
