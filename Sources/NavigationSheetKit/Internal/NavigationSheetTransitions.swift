#if os(iOS)
import SwiftUI

/// Remembers which way the path last moved.
///
/// A transition has to know whether it is animating a push or a pop, and the view being
/// popped is the one that needs the answer *after* its own state is gone. Reference
/// semantics are the point: SwiftUI captures this tracker when it builds a transition, and
/// reads the direction later, at animation time, from whatever the tracker says then.
@MainActor
final class NavigationSheetDirectionTracker {
  private var previousCount = 0
  private(set) var isForward = true

  /// The sheet's width, which is how far a screen has to travel to leave the screen.
  var containerWidth: CGFloat = 0

  func update(pathCount: Int) {
    guard pathCount != previousCount else { return }
    isForward = pathCount > previousCount
    previousCount = pathCount
  }

  func reset() {
    previousCount = 0
    isForward = true
  }
}

/// The default push/pop slide: in from the trailing edge, out to the leading edge, reversed
/// on a pop, blurring and fading as it goes.
struct NavigationSheetPushPopTransition: Transition {
  let tracker: NavigationSheetDirectionTracker

  func body(content: Content, phase: TransitionPhase) -> some View {
    let width = max(tracker.containerWidth, 1)
    let offset: CGFloat = switch phase {
      case .willAppear: tracker.isForward ? width : -width
      case .identity: 0
      case .didDisappear: tracker.isForward ? -width : width
    }
    content
      .offset(x: offset)
      .blur(radius: phase.isIdentity ? 0 : NavigationSheetMetrics.transitionBlurRadius)
      .opacity(phase.isIdentity ? 1 : 0)
  }
}

/// Hides a screen that is behind the current one without removing it.
///
/// Screens stay in the hierarchy for as long as they are on the path, so their `@State`
/// survives a round trip. This is what makes them invisible in the meantime: pushed aside,
/// blurred, transparent, and taken out of hit testing and accessibility.
struct NavigationSheetBehindEffect: ViewModifier {
  let isBehind: Bool
  let containerWidth: CGFloat

  func body(content: Content) -> some View {
    let width = max(containerWidth, 1)
    content
      .offset(x: isBehind ? -width : 0)
      .blur(radius: isBehind ? NavigationSheetMetrics.transitionBlurRadius : 0)
      .opacity(isBehind ? 0 : 1)
      .allowsHitTesting(!isBehind)
      .accessibilityHidden(isBehind)
  }
}

/// Sizes to the current screen while laying out all of them.
///
/// A `ZStack` would size to the tallest screen, which makes the sheet jump to the height of
/// whatever is deepest in the path. This gives every subview the full proposal — a screen
/// mid-slide has to be its real size — but reports only the current one's height upward, so
/// the detent follows the screen you are actually looking at.
struct NavigationSheetCurrentScreenLayout: Layout {
  let currentIndex: Int

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard subviews.indices.contains(currentIndex) else { return .zero }
    return subviews[currentIndex].sizeThatFits(proposal)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for subview in subviews {
      subview.place(at: bounds.origin, anchor: .topLeading, proposal: proposal)
    }
  }
}
#endif
