#if os(iOS)
import SwiftUI
import UIKit

/// The presented view controller: the UIKit spine of one navigation sheet.
///
/// It owns what UIKit is better at than SwiftUI's sheet — *when* things happen. The detent is
/// a single custom detent whose resolved value the controller changes in place with
/// `invalidateDetents()`, so a resize is one statement instead of the port's offer-both →
/// yield → select → sleep → prune choreography. A push animates the incoming screen and the
/// detent change inside the same animation, which SwiftUI cannot express at all. And the
/// content is laid out before the presentation animation starts, so the sheet's first frame
/// is already the right height — the initial-detent glitch stops existing rather than being
/// papered over.
final class NavigationSheetController: UIViewController {
  /// Shared state between this spine and the SwiftUI skin.
  let model: NavigationSheetModel
  /// Resolves path values to screens.
  let destinationRegistry: NavigationSheetDestinationRegistry
  /// Builds the root screen's content.
  private let root: () -> AnyView
  /// Tells the presenter the path changed from inside — back button, edge swipe, dismiss action.
  var onPathPop: (Int) -> Void = { _ in }

  /// The screens, root first. All kept alive so their state survives, exactly like the port.
  private var screens: [NavigationSheetScreenController] = []
  /// The bar, pinned over the screens.
  private var barController: NavigationSheetBarController?
  /// The replaced sheet background, hosted behind everything.
  private var backgroundController: UIHostingController<AnyView>?
  /// The height the custom detent currently resolves to, `nil` meaning "as large as allowed".
  private var targetDetentHeight: CGFloat?
  /// The most recent maximum detent value the resolver saw, for the large cap and `isLargeDetent`.
  private var resolvedMaximumHeight: CGFloat = 0
  /// The identifier of the sheet's single detent.
  private static let detentIdentifier = UISheetPresentationController.Detent.Identifier("navigationSheetKit.content")
  /// The transition currently animating, if any. Superseding it must go through
  /// ``beginTransition()`` so its completion cannot fire against reassigned roles.
  private var transitionAnimator: UIViewPropertyAnimator?
  /// Cleanup owed by the in-flight transition — removing popped screens, typically. Runs on
  /// completion, or immediately when the transition is superseded.
  private var pendingTransitionCleanup: (() -> Void)?

  init(
    model: NavigationSheetModel,
    destinationRegistry: NavigationSheetDestinationRegistry,
    root: @escaping () -> AnyView
  ) {
    self.model = model
    self.destinationRegistry = destinationRegistry
    self.root = root
    super.init(nibName: nil, bundle: nil)
    model.pop = { [weak self] in self?.popFromInside() }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear

    installBackground()
    installScreen(makeScreen(depth: 0, content: root()), animated: false)
    installBar()
    installPopGesture()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateContainerInsets()
    // Layout runs before the presentation animation, which means the root screen measures
    // and the detent resolves to the right height before anything is on screen.
    view.layoutIfNeeded()
    applyDetentForTopScreen(animated: false)
  }

  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    updateContainerInsets()
  }

  /// Publishes the sheet's own safe area insets — a known value, not a heuristic.
  ///
  /// This controller is the presented sheet, and a sheet sits on the screen's bottom edge, so
  /// `view.safeAreaInsets.bottom` *is* the home-indicator inset for this presentation — zero
  /// exactly on devices with a physical home button. The SwiftUI implementation had to probe
  /// the window with a spy view and report a frame late; here UIKit hands us the answer
  /// synchronously and tells us when it changes.
  private func updateContainerInsets() {
    let insets = view.safeAreaInsets
    let edgeInsets = EdgeInsets(
      top: insets.top,
      leading: insets.left,
      bottom: insets.bottom,
      trailing: insets.right
    )
    if model.containerInsets != edgeInsets {
      model.containerInsets = edgeInsets
    }
  }

  // MARK: - Sheet Configuration

  /// Configures the presentation. Called by the presenter before presenting.
  func configureSheet() {
    guard let sheet = sheetPresentationController else { return }
    sheet.detents = [makeDetent()]
    sheet.selectedDetentIdentifier = Self.detentIdentifier
    sheet.prefersGrabberVisible = false
    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
  }

  private func makeDetent() -> UISheetPresentationController.Detent {
    .custom(identifier: Self.detentIdentifier) { [weak self] context in
      guard let self else { return context.maximumDetentValue }
      resolvedMaximumHeight = context.maximumDetentValue
      let resolved = min(targetDetentHeight ?? context.maximumDetentValue, context.maximumDetentValue)
      updateIsLargeDetent(resolvedHeight: resolved)
      return resolved
    }
  }

  private func updateIsLargeDetent(resolvedHeight: CGFloat) {
    let isLarge = resolvedMaximumHeight > 0 && resolvedHeight >= resolvedMaximumHeight
    if model.isLargeDetent != isLarge {
      model.isLargeDetent = isLarge
    }
  }

  /// Points the detent at the top screen's requested height and animates the change.
  ///
  /// This is the whole detent story: mutate the target, invalidate, done. No detent-set
  /// juggling, because the detent's *value* changes rather than which detent is selected.
  private func applyDetentForTopScreen(animated: Bool) {
    guard let top = screens.last else { return }

    let newTarget: CGFloat?
    switch top.requestedDetentHeight {
      case .explicit(let detent):
        // An explicit PresentationDetent from the public API. `.height`/`.fraction`/`.medium`
        // map to heights against the resolved maximum; `.large` and anything else mean full.
        newTarget = resolveExplicitDetent(detent)

      case .height(let height):
        newTarget = height

      case .unknown:
        // No answer yet — stay where we are rather than guess and correct.
        return
    }

    guard newTarget != targetDetentHeight else { return }
    targetDetentHeight = newTarget

    guard let sheet = sheetPresentationController else { return }
    if animated {
      sheet.animateChanges {
        sheet.invalidateDetents()
      }
    } else {
      sheet.invalidateDetents()
    }
  }

  /// Maps a public `PresentationDetent` to a height target, or `nil` for full height.
  ///
  /// `PresentationDetent` is opaque, so the mapping goes through the port's trick in reverse:
  /// the well-known cases are compared directly, and `.height`/`.fraction` values are
  /// recovered by resolving against the current maximum.
  private func resolveExplicitDetent(_ detent: PresentationDetent) -> CGFloat? {
    if detent == .large {
      return nil
    }
    if detent == .medium {
      return resolvedMaximumHeight > 0 ? resolvedMaximumHeight / 2 : nil
    }
    for height in stride(from: CGFloat(1), through: 4000, by: 1) where detent == .height(height) {
      return height
    }
    for percent in 1...100 where detent == .fraction(CGFloat(percent) / 100) {
      return resolvedMaximumHeight * CGFloat(percent) / 100
    }
    return nil
  }

  // MARK: - Screens

  private func makeScreen(depth: Int, content: AnyView) -> NavigationSheetScreenController {
    let screen = NavigationSheetScreenController(depth: depth, model: model, content: content)
    screen.onSizingChange = { [weak self, weak screen] in
      guard let self, let screen, screen === screens.last else { return }
      applyDetentForTopScreen(animated: presentedOnScreen)
    }
    return screen
  }

  /// Whether the sheet is visibly on screen, which decides if detent changes animate.
  private var presentedOnScreen: Bool {
    viewIfLoaded?.window != nil
  }

  private func installScreen(_ screen: NavigationSheetScreenController, animated: Bool) {
    addChild(screen)
    if let barView = barController?.view {
      view.insertSubview(screen.view, belowSubview: barView)
    } else {
      view.addSubview(screen.view)
    }
    screen.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      screen.view.topAnchor.constraint(equalTo: view.topAnchor),
      screen.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      screen.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      screen.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    screen.didMove(toParent: self)
    screens.append(screen)
    screen.setToolbarHidden(model.toolbarHiddenDepths.contains(screen.depth))
  }

  // MARK: - Path Sync

  /// Brings the screen stack in line with the path. Called by the presenter on every update.
  func setPath(_ path: NavigationSheetPath) {
    let targetDepth = path.count
    let currentDepth = screens.count - 1

    if targetDepth > currentDepth {
      // Push the missing screens; only the last push animates.
      let elements = path.identifiedElements
      for depth in (currentDepth + 1)...targetDepth {
        let element = elements[depth - 1].element
        guard let destination = destinationRegistry.destination(for: element) else {
          NavigationSheetLog.fault("No destination registered for path value: \(String(describing: element))")
          onPathPop(depth - 1)
          return
        }
        push(destination, depth: depth, animated: depth == targetDepth && presentedOnScreen)
      }
    } else if targetDepth < currentDepth {
      pop(to: targetDepth, animated: presentedOnScreen)
    }
  }

  // MARK: - Transitions

  /// Ends whatever transition is in flight and finalizes its bookkeeping, so a new one can
  /// start from a clean slate.
  ///
  /// This is what makes fast navigation safe. Without it, a superseded animator's completion
  /// fires late and applies an end-state to views whose roles have changed since — a push's
  /// "hide the previous screen" landing on the screen a pop just revealed, which leaves the
  /// sheet visibly empty.
  private func beginTransition() {
    if let animator = transitionAnimator {
      transitionAnimator = nil
      animator.stopAnimation(true)
    }
    pendingTransitionCleanup?()
    pendingTransitionCleanup = nil
  }

  /// Runs a transition animation whose completion cannot act stale: it is skipped outright if
  /// another transition superseded it, and the final state comes from ``settleScreens()``
  /// rather than from views captured when the animation began.
  private func runTransition(cleanup: (() -> Void)? = nil, animations: @escaping () -> Void) {
    pendingTransitionCleanup = cleanup

    let animator = UIViewPropertyAnimator(
      duration: NavigationSheetMetrics.animationDuration,
      timingParameters: UISpringTimingParameters(dampingRatio: 1)
    )
    animator.addAnimations(animations)
    animator.addCompletion { [weak self] _ in
      guard let self, transitionAnimator === animator else { return }
      transitionAnimator = nil
      pendingTransitionCleanup?()
      pendingTransitionCleanup = nil
      settleScreens()
    }
    transitionAnimator = animator
    animator.startAnimation()
  }

  /// Puts every screen in its resting state: the top one visible and in place, the rest
  /// hidden. The single source of truth for what the stack looks like between transitions.
  private func settleScreens() {
    guard let top = screens.last else { return }
    for screen in screens {
      let isTop = screen === top
      screen.view.isHidden = !isTop
      screen.view.transform = .identity
      screen.view.alpha = isTop ? 1 : screen.view.alpha
    }
    top.view.alpha = 1
  }

  private func push(_ content: AnyView, depth: Int, animated: Bool) {
    beginTransition()

    let previous = screens.last
    let screen = makeScreen(depth: depth, content: content)
    installScreen(screen, animated: animated)
    model.currentDepth = depth

    guard animated, let previous else {
      settleScreens()
      applyDetentForTopScreen(animated: animated)
      return
    }

    // Lay the new screen out now so it measures before the animation starts — that is what
    // lets the slide and the resize run as one gesture instead of slide-then-correct.
    view.layoutIfNeeded()

    let width = view.bounds.width
    screen.view.transform = CGAffineTransform(translationX: width, y: 0)
    screen.view.alpha = 0

    runTransition {
      screen.view.transform = .identity
      screen.view.alpha = 1
      previous.view.transform = CGAffineTransform(translationX: -width, y: 0)
      previous.view.alpha = 0
    }

    // The detent change rides alongside the slide — the coordinated push-and-resize the
    // SwiftUI port could not express.
    applyDetentForTopScreen(animated: true)
  }

  private func pop(to targetDepth: Int, animated: Bool) {
    guard screens.count - 1 > targetDepth else { return }

    beginTransition()

    let removed = Array(screens[(targetDepth + 1)...])
    let revealed = screens[targetDepth]
    screens.removeLast(removed.count)
    model.currentDepth = targetDepth

    revealed.view.isHidden = false

    let width = view.bounds.width
    let removeDeparted: () -> Void = {
      for screen in removed {
        screen.willMove(toParent: nil)
        screen.view.removeFromSuperview()
        screen.removeFromParent()
      }
    }

    guard animated, let departing = removed.last else {
      removeDeparted()
      settleScreens()
      applyDetentForTopScreen(animated: animated)
      return
    }

    // Intermediate screens of a multi-pop vanish immediately; only the top one slides out.
    for screen in removed.dropLast() {
      screen.view.isHidden = true
    }

    revealed.view.transform = CGAffineTransform(translationX: -width, y: 0)
    revealed.view.alpha = 0

    runTransition(cleanup: removeDeparted) {
      departing.view.transform = CGAffineTransform(translationX: width, y: 0)
      departing.view.alpha = 0
      revealed.view.transform = .identity
      revealed.view.alpha = 1
    }

    applyDetentForTopScreen(animated: true)
  }

  /// A pop initiated inside the sheet — back button, dismiss action, edge swipe.
  private func popFromInside() {
    guard screens.count > 1 else { return }
    let newDepth = screens.count - 2
    // The binding is the source of truth: mutate it and let setPath do the popping when the
    // update comes back around. If no binding was passed, the presenter pops us directly.
    onPathPop(newDepth)
  }

  // MARK: - Bar

  private func installBar() {
    let bar = NavigationSheetBarController(model: model)
    addChild(bar)
    view.addSubview(bar.view)
    bar.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      bar.view.topAnchor.constraint(equalTo: view.topAnchor),
      bar.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      bar.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])
    bar.didMove(toParent: self)
    barController = bar
  }

  // MARK: - Background

  private func installBackground() {
    // Always clear, and the surface underneath is drawn in SwiftUI instead: whether the
    // background was replaced is no longer knowable here, since a screen declares its own
    // through a preference that cannot arrive until a layout pass after this one. Deciding it
    // here would leave an opaque system surface under a translucent panel.
    view.backgroundColor = .clear
    let host = UIHostingController<AnyView>(rootView: AnyView(NavigationSheetBackgroundContent(model: model)))
    host.view.backgroundColor = .clear
    addChild(host)
    view.insertSubview(host.view, at: 0)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      host.view.topAnchor.constraint(equalTo: view.topAnchor),
      host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    host.didMove(toParent: self)
    backgroundController = host
  }

  // MARK: - Interactive Pop

  private func installPopGesture() {
    let gesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
    gesture.edges = .left
    view.addGestureRecognizer(gesture)
  }

  @objc
  private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
    guard screens.count > 1 else { return }
    let departing = screens[screens.count - 1]
    let revealed = screens[screens.count - 2]
    let width = view.bounds.width
    let progress = max(0, min(1, gesture.translation(in: view).x / width))

    switch gesture.state {
      case .began:
        // Whatever is mid-flight yields to the finger, and its bookkeeping runs now so the
        // gesture starts from settled screens.
        beginTransition()
        settleScreens()
        revealed.view.isHidden = false
        revealed.view.transform = CGAffineTransform(translationX: -width, y: 0)
        revealed.view.alpha = 0

      case .changed:
        departing.view.transform = CGAffineTransform(translationX: progress * width, y: 0)
        departing.view.alpha = 1 - progress * 0.5
        revealed.view.transform = CGAffineTransform(translationX: (progress - 1) * width, y: 0)
        revealed.view.alpha = progress

      case .ended, .cancelled:
        let velocity = gesture.velocity(in: view).x
        let shouldPop = gesture.state == .ended && (progress > 0.4 || velocity > 500)
        if shouldPop {
          // Commit the pop up front: the screen leaves the stack, the binding hears about
          // it, and the animation is just the tail. The binding round-trip through setPath
          // finds the counts already matching and does nothing.
          let departed = screens.removeLast()
          model.currentDepth = screens.count - 1
          runTransition(cleanup: {
            departed.willMove(toParent: nil)
            departed.view.removeFromSuperview()
            departed.removeFromParent()
          }) {
            departed.view.transform = CGAffineTransform(translationX: width, y: 0)
            departed.view.alpha = 0
            revealed.view.transform = .identity
            revealed.view.alpha = 1
          }
          applyDetentForTopScreen(animated: true)
          onPathPop(screens.count - 1)
        } else {
          runTransition {
            departing.view.transform = .identity
            departing.view.alpha = 1
            revealed.view.transform = CGAffineTransform(translationX: -width, y: 0)
            revealed.view.alpha = 0
          }
        }

      default:
        break
    }
  }
}

/// The replaced sheet background plus the current screen's overlay, crossfading per depth.
private struct NavigationSheetBackgroundContent: View {
  let model: NavigationSheetModel

  var body: some View {
    ZStack {
      if let background = model.resolvedBackground {
        background
      } else {
        // "Nothing replaced it" means the system's sheet surface. Drawn here rather than as
        // the container's colour, because a screen's own background arrives a layout pass
        // after the sheet is presented — so this branch has to be able to give way.
        Color(.systemBackground)
          .transition(.opacity)
      }

      if let overlay = model.backgroundOverlaysByDepth[model.currentDepth] {
        overlay
          .id(model.currentDepth)
          .transition(.opacity.animation(.smooth))
      }
    }
    .animation(.smooth, value: model.isLargeDetent)
    .animation(.smooth(duration: NavigationSheetMetrics.animationDuration), value: model.hasReplacedBackground)
    .ignoresSafeArea()
    .environment(\.navigationSheetIsLargeDetent, model.isLargeDetent)
    .environment(\.self, model.environment)
  }
}
#endif
