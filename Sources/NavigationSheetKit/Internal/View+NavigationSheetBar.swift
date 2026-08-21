#if os(iOS)
import SwiftUI

extension View {
  /// Places the sheet's bar in the top safe area.
  ///
  /// `safeAreaBar` on iOS 26 and later, which brings its own progressive blur and control
  /// sizing; `safeAreaInset` below that, with a fading material behind it. Either way the
  /// bar sits outside the content's safe area, so content scrolls under it rather than
  /// starting below it.
  ///
  /// - Parameters:
  ///   - background: A caller-supplied bar background, or `nil` for the platform default.
  ///   - content: The bar itself.
  @ViewBuilder
  func navigationSheetBar<Bar: View>(
    background: AnyView?,
    @ViewBuilder content: () -> Bar
  ) -> some View {
    let bar = content()
    transform { view in
      if #available(iOS 26.0, *) {
        view.safeAreaBar(edge: .top, spacing: 0) {
          bar.background {
            // Nothing by default — safeAreaBar draws its own treatment.
            if let background {
              background
            }
          }
        }
      } else {
        view.safeAreaInset(edge: .top, spacing: 0) {
          bar.background {
            if let background {
              background
            } else {
              NavigationSheetDefaultBarBackground()
            }
          }
        }
      }
    }
  }
}
#endif
