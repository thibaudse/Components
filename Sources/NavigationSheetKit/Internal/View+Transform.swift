#if os(iOS)
import SwiftUI

extension View {
  /// Applies a transformation to this view inline, so an `if #available` can pick between
  /// two modifiers without splitting the surrounding chain into a `@ViewBuilder` property.
  @ViewBuilder
  func transform<Transformed: View>(@ViewBuilder _ transform: (Self) -> Transformed) -> Transformed {
    transform(self)
  }
}
#endif
