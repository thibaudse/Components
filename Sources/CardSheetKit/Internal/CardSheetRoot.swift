#if os(iOS)
import SwiftUI
import UIKit

/// The content of the SwiftUI sheet that `.sheet(…, style: .card)` and `.sheet(items:selection:)` present: every page drawn as a card, where
/// the engine says. Being the sheet's own content is what lets SwiftUI's presentation modifiers
/// inside a page reach the sheet, where the engine reads them back.
@available(iOS 26.0, *)
struct CardSheetRoot<Page: Identifiable, Content: View>: View {
  let pages: [Page]
  let startIndex: Int
  let dismiss: () -> Void
  let pageChanged: (Int) -> Void
  let content: (Page) -> Content

  @State private var engine = CardSheetEngine()

  var body: some View {
    ZStack(alignment: .topLeading) {
      ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
        CardPage(engine: engine, index: index) { content(page) }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .overlay(alignment: .topLeading) { CardSheetState(engine: engine) }
    .opacity(engine.isAttached ? 1 : 0)
    .background(SheetProbe(engine: engine))
    .ignoresSafeArea()
    .onPreferenceChange(CardSheetOptionsKey.self) { options in
      MainActor.assumeIsolated { engine.options = options }
    }
    .onAppear {
      engine.onDismiss = dismiss
      engine.onPageChange = pageChanged
      engine.start(pageCount: pages.count, at: startIndex)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("cardSheet")
  }
}

/// One card. Only this view reads the engine's per-frame values, so a moving card redraws its
/// frame and shape, not its content.
@available(iOS 26.0, *)
private struct CardPage<Content: View>: View {
  let engine: CardSheetEngine
  let index: Int
  @ViewBuilder let content: Content

  var body: some View {
    let frame = engine.frame(for: index)
    let top = Edge.Corner.Style.concentric(minimum: .fixed(engine.topCornerMinimum))
    let bottom = Edge.Corner.Style.concentric(minimum: .fixed(engine.restingCornerRadius))
    content
      // The content's top safe area is UIKit's own: exactly as much of the status bar as the
      // card has risen into. At the bottom, the card adds the home indicator's. (No
      // `ignoresSafeArea` here: the host gives SwiftUI no safe area, and with it SwiftUI
      // re-placed the content — animated — whenever UIKit's changed as a card left the zone.)
      .safeAreaPadding(.bottom, engine.contentBottomInset)
      .frame(width: frame.width, height: engine.contentHeight, alignment: .top)
      .background(.background)
      // The visible part, clipped to the card's shape: each corner concentric with the
      // display's own, as far as it is from it — a floating card's bottom ones, a full-screen
      // card's all four. Attached, the card runs past the display's bottom far enough that its
      // bottom corners are never seen.
      .frame(width: frame.width, height: engine.visibleHeight, alignment: .top)
      .clipShape(ConcentricRectangle(
        topLeadingCorner: top, topTrailingCorner: top,
        bottomLeadingCorner: bottom, bottomTrailingCorner: bottom
      ))
      .overlay(alignment: .top) {
        Capsule()
          .fill(.white.opacity(0.55))
          .frame(width: 36, height: 5)
          .padding(.top, 7)
          .opacity(engine.grabberOpacity)
          .allowsHitTesting(false)
      }
      .opacity(engine.opacity(for: index))
      // Placed by layout, not `offset`: an offset only moves what SwiftUI draws, and the
      // content's scroll view — a UIKit view inside — followed it several frames late, so
      // the content jumped to catch up with its own card.
      .position(x: frame.midX, y: frame.minY + engine.visibleHeight / 2)
      .environment(\.presentationExpansion, engine.expansion)
  }
}

/// Where the current card is, for UI tests: a SwiftUI `offset` moves what is drawn but not the
/// accessibility frame, so XCUITest cannot read a card's position from the card itself.
private struct CardSheetState: View {
  let engine: CardSheetEngine

  var body: some View {
    Color.clear
      .frame(width: 1, height: 1)
      .accessibilityElement()
      .accessibilityIdentifier("cardSheet.state")
      .accessibilityValue("top=\(Int((engine.cardTop + engine.dismissOffset).rounded())) left=\(Int(engine.frame(for: engine.currentIndex).minX.rounded())) page=\(engine.currentIndex) bottom=\(Int(engine.visibleBottom.rounded())) grabber=\(Int(engine.grabberOpacity)) scroll=\(Int(engine.contentScrolled.rounded())) large=\(Int(engine.largeTop.rounded()))")
  }
}

/// Sits inside the sheet's content; once in a window it hands the engine its way into UIKit.
private struct SheetProbe: UIViewRepresentable {
  let engine: CardSheetEngine

  func makeUIView(context: Context) -> ProbeView {
    let view = ProbeView()
    view.engine = engine
    view.isUserInteractionEnabled = false
    return view
  }

  func updateUIView(_ uiView: ProbeView, context: Context) {}

  final class ProbeView: UIView {
    weak var engine: CardSheetEngine?

    override func didMoveToWindow() {
      super.didMoveToWindow()
      guard window != nil else { return }
      engine?.attach(from: self)
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      engine?.layoutDidChange()
    }
  }
}
#endif
