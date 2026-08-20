import SwiftUI

private struct BlurModifier: ViewModifier {
  let radius: CGFloat

  func body(content: Content) -> some View {
    content.blur(radius: radius)
  }
}

extension AnyTransition {
  /// The default month transition: a slide in the direction of travel, combined with a
  /// blur and a fade. Replaceable with ``CalendarView/calendarTransition(_:)``.
  static func month(direction: CalendarNavigationDirection) -> AnyTransition {
    let slide: AnyTransition = switch direction {
      case .forward:
        .asymmetric(
          insertion: .move(edge: .trailing),
          removal: .move(edge: .leading)
        )

      case .backward:
        .asymmetric(
          insertion: .move(edge: .leading),
          removal: .move(edge: .trailing)
        )
    }

    return slide
      .combined(with: .modifier(active: BlurModifier(radius: 10), identity: BlurModifier(radius: 0)))
      .combined(with: .opacity)
  }
}
