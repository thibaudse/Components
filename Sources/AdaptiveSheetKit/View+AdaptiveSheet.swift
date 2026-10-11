#if os(iOS)
import SwiftUI

public extension View {
  /// Presents a sheet that is as tall as its content, while `isPresented` is true.
  ///
  /// ```swift
  /// .adaptiveSheet(isPresented: $isShowingTip) {
  ///     TipView(onGotIt: { isShowingTip = false })
  ///         .presentationDragIndicator(.visible)
  /// }
  /// ```
  ///
  /// **It is `sheet(isPresented:onDismiss:content:)` with the detent taken care of**, and nothing else
  /// changes: the `.presentation*` modifiers go inside `content` exactly as they would on a plain sheet
  /// and keep working. Static content is measured as laid out; a `ScrollView` is measured by its content
  /// size, so it hugs what it scrolls rather than the sheet it sits in. The sheet resizes, animated,
  /// whenever the content does — and inside a `NavigationStack`, whenever a push or a pop puts another
  /// screen on top, sized to that screen.
  ///
  /// **Content taller than the screen stops at the large detent**, and scrolling past it is the
  /// caller's — wrap static content in a `ScrollView` when it can outgrow the screen. Do not add
  /// `presentationDetents(_:)` inside: the height is this modifier's, and it replaces any detents set
  /// there.
  ///
  /// - Parameters:
  ///   - isPresented: Whether the sheet is showing. Swiping it away sets this to `false`.
  ///   - onDismiss: What to run once the sheet has gone.
  ///   - content: What the sheet shows.
  func adaptiveSheet<Content: View>(
    isPresented: Binding<Bool>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    sheet(isPresented: isPresented, onDismiss: onDismiss) {
      content().sizedToAdaptiveSheet()
    }
  }

  /// Presents a sheet that is as tall as its content, for as long as `item` is non-nil.
  ///
  /// The `sheet(item:onDismiss:content:)` counterpart of ``adaptiveSheet(isPresented:onDismiss:content:)``,
  /// with the same contract: `content` is only built with a non-nil item, and a new item's identity
  /// replaces the sheet rather than updating it.
  ///
  /// - Parameters:
  ///   - item: The sheet's subject. Swiping the sheet away sets this to `nil`.
  ///   - onDismiss: What to run once the sheet has gone.
  ///   - content: What the sheet shows for the item.
  func adaptiveSheet<Item: Identifiable, Content: View>(
    item: Binding<Item?>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Item) -> Content
  ) -> some View {
    sheet(item: item, onDismiss: onDismiss) { item in
      content(item).sizedToAdaptiveSheet()
    }
  }
}

private extension View {
  /// Measures this view and sizes the sheet it sits in to the measurement.
  ///
  /// The bridge reads the preference the measuring modifier publishes, so it has to sit outside it.
  func sizedToAdaptiveSheet() -> some View {
    modifier(AdaptiveSheetMeasuringModifier())
      .backgroundPreferenceValue(AdaptiveSheetMeasurementKey.self) { reading in
        AdaptiveSheetDetentBridge(reading: reading)
          .frame(width: 0, height: 0)
          .accessibilityHidden(true)
      }
  }
}
#endif
