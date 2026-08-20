import SwiftUI

/// The direction a calendar is moving through time, used to pick a transition.
enum NavigationDirection: Equatable {
  case backward, forward

  /// The direction of travel between two days.
  ///
  /// Any move that is not backward counts as forward, including a move to the same day,
  /// so a calendar never lacks a direction to animate with.
  init(from current: DateComponents, to target: DateComponents) {
    self = target < current ? .backward : .forward
  }
}

private struct BlurModifier: ViewModifier {
  let radius: CGFloat

  func body(content: Content) -> some View {
    content.blur(radius: radius)
  }
}

extension AnyTransition {
  /// A slide in the direction of travel, combined with a blur and a fade.
  ///
  /// Passing `nil` yields `.identity`, so the first month a calendar shows does not
  /// animate in from an arbitrary edge.
  static func month(direction: NavigationDirection?) -> AnyTransition {
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

      case .none:
        .identity
    }

    return slide
      .combined(with: .modifier(active: BlurModifier(radius: 10), identity: BlurModifier(radius: 0)))
      .combined(with: .opacity)
  }
}
