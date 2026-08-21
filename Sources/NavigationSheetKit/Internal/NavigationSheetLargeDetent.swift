#if os(iOS)
import SwiftUI

/// `.large`, but it tells us how tall it turned out to be.
///
/// Auto-sizing needs a ceiling: a screen taller than the sheet can ever be should sit at
/// `.large` rather than at a fixed height nobody can reach. `PresentationDetent.large` will
/// not say what height that is, so this custom detent resolves to the same value and
/// records it on the way through.
struct NavigationSheetLargeDetent: CustomPresentationDetent {
  @MainActor static var resolvedHeight: CGFloat = 0

  static func height(in context: Context) -> CGFloat? {
    let height = context.maxDetentValue
    MainActor.assumeIsolated {
      resolvedHeight = height
    }
    return height
  }
}

extension PresentationDetent {
  /// Equivalent to `.large`, and captures the height it resolved to.
  static let sheetLarge = PresentationDetent.custom(NavigationSheetLargeDetent.self)
}
#endif
