#if os(iOS)
import SwiftUI

/// The stack of screens: the root, plus one per path entry.
///
/// Every screen stays in the hierarchy for as long as it is on the path, which is what keeps
/// its `@State` alive across a push and pop. Only screens actually popped are removed, and
/// those are the only ones a transition runs on; the rest are hidden by
/// ``NavigationSheetBehindEffect``.
struct NavigationSheetBody<SheetRoot: View, SheetTransition: Transition>: View {
  @Environment(\.navigationSheetRegistry) private var destinationRegistry
  @Environment(\.navigationSheetWindowInsets) private var windowInsets

  let transition: SheetTransition?
  let directionTracker: NavigationSheetDirectionTracker
  let root: () -> SheetRoot

  @Binding var path: NavigationSheetPath

  /// Bottom margin for devices with a physical home button. Devices with a home indicator
  /// already have that space; devices without one leave content flush against the edge.
  private var bottomSafeAreaPadding: CGFloat {
    windowInsets.bottom == 0 ? NavigationSheetMetrics.homeButtonBottomPadding : 0
  }

  var body: some View {
    // Updated here, during body evaluation, because SwiftUI resolves the transitions for
    // appearing and disappearing screens straight afterwards — a tracker updated in
    // `onChange` would already be a frame late.
    let _ = directionTracker.update(pathCount: path.count)
    let currentDepth = path.count

    NavigationSheetCurrentScreenLayout(currentIndex: currentDepth) {
      root()
        .safeAreaPadding(.bottom, bottomSafeAreaPadding)
        .environment(\.navigationSheetPathDepth, 0)
        .modifier(NavigationSheetContentMeasurementModifier(pathDepth: 0))
        .modifier(NavigationSheetBehindEffect(
          isBehind: currentDepth > 0,
          containerWidth: directionTracker.containerWidth
        ))

      ForEach(path.identifiedElements) { entry in
        if let destination = destinationRegistry?.destination(for: entry.element) {
          destination
            .safeAreaPadding(.bottom, bottomSafeAreaPadding)
            .environment(\.navigationSheetPathDepth, entry.depth)
            .modifier(NavigationSheetContentMeasurementModifier(pathDepth: entry.depth))
            .modifier(NavigationSheetBehindEffect(
              isBehind: entry.depth < currentDepth,
              containerWidth: directionTracker.containerWidth
            ))
            .modifier(TransitionResolver(
              transition: transition,
              directionTracker: directionTracker
            ))
        } else {
          // Pushed with nothing to show. Popping is the recoverable answer — leaving it would
          // strand the sheet on a blank screen with a back button that works, which looks
          // like a bug in the app rather than a missing registration.
          Color.clear
            .onAppear {
              NavigationSheetLog.fault("No destination registered for path value: \(String(describing: entry.element))")
              path.removeLast()
            }
        }
      }
    }
    .onGeometryChange(for: CGFloat.self, of: \.size.width) { directionTracker.containerWidth = $0 }
    .animation(.snappy(duration: NavigationSheetMetrics.animationDuration), value: path)
  }

  /// The caller's transition if they gave one, the default slide otherwise.
  private struct TransitionResolver: ViewModifier {
    let transition: SheetTransition?
    let directionTracker: NavigationSheetDirectionTracker

    func body(content: Content) -> some View {
      if let transition {
        content.transition(transition)
      } else {
        content.transition(NavigationSheetPushPopTransition(tracker: directionTracker))
      }
    }
  }
}
#endif
