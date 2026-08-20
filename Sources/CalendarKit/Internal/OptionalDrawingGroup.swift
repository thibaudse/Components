import SwiftUI

/// Applies `drawingGroup()` only when the caller has left it enabled.
///
/// Rasterizing the grid offscreen is a measurable win on the month transition, so it is
/// the default. It is a modifier rather than a fixed call because the grid contains views
/// the component does not own.
struct OptionalDrawingGroup: ViewModifier {
  let isEnabled: Bool

  func body(content: Content) -> some View {
    if isEnabled {
      content.drawingGroup()
    } else {
      content
    }
  }
}
