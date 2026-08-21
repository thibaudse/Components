#if os(iOS)
import SwiftUI

/// Applies the sheet's default toolbar button style, which follows the detent.
///
/// SwiftUI's own toolbar styles the buttons you put in it; this does the same, and for the
/// same reason — a bare `Button` in a bar looks like unstyled text. A sheet at its large
/// detent is a screen and gets glass on iOS 26; a short sheet is a card, where glass over
/// content reads as a mistake, so it gets `.bordered`.
///
/// Everything here is replaceable: `.navigationSheetToolbarButtonStyle(.hidden)` turns it
/// off, and your own `.buttonStyle(_:)` applies as normal.
struct NavigationSheetToolbarButtonStyleModifier: ViewModifier {
  @Environment(\.navigationSheetIsLargeDetent) private var isLargeDetent

  @State private var areAnimationsEnabled = false

  func body(content: Content) -> some View {
    ZStack {
      if #available(iOS 26.0, *), isLargeDetent {
        content
          .buttonStyle(.glass)
          .transition(.blurReplace)
      } else {
        content
          .buttonStyle(.bordered)
          .transition(.blurReplace)
      }
    }
    .animation(areAnimationsEnabled ? .smooth : nil, value: isLargeDetent)
    // The sheet settles on its first detent right after presenting. Animating that would
    // crossfade the buttons on the way in, which reads as a glitch rather than a change.
    .task {
      try? await Task.sleep(for: .seconds(NavigationSheetMetrics.animationDuration))
      areAnimationsEnabled = true
    }
  }
}
#endif
