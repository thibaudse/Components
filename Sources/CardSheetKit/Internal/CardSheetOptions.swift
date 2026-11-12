#if os(iOS)
import SwiftUI

/// The card has already left the screen when the binding changes: SwiftUI's own dismissal must
/// not animate anything after it.
@MainActor
func withoutAnimation(_ change: () -> Void) {
  var transaction = Transaction(animation: nil)
  transaction.disablesAnimations = true
  withTransaction(transaction, change)
}

/// The one page of a sheet presenting a single view.
struct SinglePage: Identifiable {
  let id = 0
}

/// Each modifier sets only its own field; the rest stay nil and fall back to the default.
struct CardSheetOptions: Equatable {
  var snapping: PresentationSnapping?
  var expandsToFullScreen: Bool?
  var neighbourPeek: CGFloat?

  func merged(with other: CardSheetOptions) -> CardSheetOptions {
    CardSheetOptions(
      snapping: other.snapping ?? snapping,
      expandsToFullScreen: other.expandsToFullScreen ?? expandsToFullScreen,
      neighbourPeek: other.neighbourPeek ?? neighbourPeek
    )
  }
}

/// Carries the options up from the content to the sheet.
struct CardSheetOptionsKey: PreferenceKey {
  static let defaultValue = CardSheetOptions()
  static func reduce(value: inout CardSheetOptions, nextValue: () -> CardSheetOptions) {
    value = value.merged(with: nextValue())
  }
}
#endif
