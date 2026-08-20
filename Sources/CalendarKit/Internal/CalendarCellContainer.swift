import SwiftUI

/// The square (or not) a day is drawn in.
///
/// Cells share the available width equally either way. With an aspect ratio the height
/// follows the width, which is what a month grid usually wants; without one the height
/// comes from the content, which is what a row of pills wants.
struct CalendarCellContainer<Content: View>: View {
  let aspectRatio: CGFloat?
  @ViewBuilder let content: Content

  var body: some View {
    if let aspectRatio {
      Color.clear
        .aspectRatio(aspectRatio, contentMode: .fit)
        .overlay { content }
        .frame(maxWidth: .infinity)
    } else {
      content
        .frame(maxWidth: .infinity)
    }
  }
}
