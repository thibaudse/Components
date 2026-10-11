#if os(iOS)
import UIKit

/// Sizes the sheet it sits in to the content's measurement.
///
/// It installs one custom detent and, as measurements arrive, changes that detent's *value* rather than
/// which detent is selected — so a resize is an invalidation, never a detent-set swap. It touches the
/// detents and nothing else: the grabber, the corner radius, the background and dismissal all belong to
/// SwiftUI's `.presentation*` modifiers.
///
/// **Content inside a `NavigationStack` is measured here, in UIKit, rather than by SwiftUI.** The
/// measurement SwiftUI publishes is one reading for the whole stack and cannot say which screen is on
/// top — after a pop, nothing re-reports and the sheet would keep the height of the screen that left. So
/// once the stack's `UINavigationController` is found, this controller watches which screen is on top,
/// measures each new one once its push or pop has finished, and follows its scroll view's content size
/// until the next. Content without a stack keeps SwiftUI's measurement.
final class AdaptiveSheetDetentController: UIViewController {
  private static let detentIdentifier = UISheetPresentationController.Detent.Identifier("AdaptiveSheetKit.adaptiveSheet")

  private var measurement: AdaptiveSheetMeasurement?
  /// The measurement the sheet was last invalidated for, so an update that changes nothing does not
  /// re-resolve the detent.
  private var appliedMeasurement: AdaptiveSheetMeasurement?
  private var hasAppeared = false
  /// Whether a resize is already waiting for the current burst of readings to finish.
  private var isResizeScheduled = false
  /// Whether a screen in the stack has been measured here yet — from the first push on. Until then the
  /// root screen is SwiftUI's to size: its reading is right while the sheet is still arriving, where
  /// UIKit's first reads of a new stack are a layout pass short.
  private var hasMeasuredScreen = false
  /// Whether `measurement` is SwiftUI's reading of the content's laid-out frame — which, for a
  /// `NavigationStack`, is the frame the sheet gave it rather than anything the content asked for.
  private var isLayoutReading = false
  /// Whether a layout reading that fills the sheet still opens it at a placeholder height instead.
  ///
  /// **SwiftUI builds a stack's navigation controller only after the sheet has appeared**, so until then
  /// the one reading of a static-root stack is the stack's own, which fills the sheet: it opened at full
  /// height and shrank. Opened at a placeholder, it grows to the root's height once the stack exists.
  /// Released just after the sheet appears when no stack turns up, so content that really fills the
  /// sheet grows to fill it rather than staying at the placeholder.
  private var holdsPlaceholder = true
  /// Whether UIKit has read a static root. SwiftUI's layout readings then say only what height the sheet
  /// gave the stack — and one that arrived after the root was read replaced it with the placeholder's.
  private var hasStaticRootReading = false

  /// The navigation controller behind the content's `NavigationStack`, once one has been found.
  private weak var navigation: UINavigationController?
  /// Checks, once a frame while a stack is on screen, whether another screen is on top.
  ///
  /// **Nothing in the stack's own machinery is touched to find out.** Standing in as the navigation
  /// controller's delegate — forwarding everything to SwiftUI's — broke every push SwiftUI started: they
  /// ran without their animation, while UIKit's own back button still animated. It runs only while a
  /// stack is on screen, and costs a pointer comparison a frame — plus a fitting-size read while the
  /// screen on top does not scroll, since nothing else reports that screen's height.
  private var displayLink: CADisplayLink?
  /// The screen the sheet was last sized for — the root, which SwiftUI sizes, until the first push.
  private weak var measuredScreen: UIViewController?
  /// The top screen's scroll view, watched so content that grows or shrinks on one screen still
  /// resizes the sheet.
  private weak var observedScrollView: UIScrollView?
  private var contentSizeObservation: NSKeyValueObservation?

  /// The hosting controller SwiftUI presented: this controller is a child of it, so the sheet — and
  /// the content's navigation controller — belong to the root of the parent chain.
  private var presentedRoot: UIViewController {
    var root: UIViewController = self
    while let parent = root.parent {
      root = parent
    }
    return root
  }

  /// The sheet this controller's content was presented in.
  private var sheet: UISheetPresentationController? {
    presentedRoot.sheetPresentationController
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false
  }

  override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    // Removed — possibly before it ever appeared, so `viewDidDisappear` would never come.
    guard parent != nil else {
      stopWatchingNavigation()
      return
    }
    attachToNavigation()
    resize()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    attachToNavigation()
    resize()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    hasAppeared = true
    attachToNavigation()
    startWatchingNavigation()
    guard navigation == nil else { return }

    // The stack is created in the pass that follows the appearance; only once that has run can its
    // absence be trusted.
    Task { @MainActor [weak self] in
      await Task.yield()
      guard let self else { return }
      self.attachToNavigation()
      if self.navigation == nil {
        self.releasePlaceholder()
      }
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    // The display link holds this controller; stopping it with the sheet is what lets both go.
    stopWatchingNavigation()
  }

  /// Takes the content's latest SwiftUI reading and resizes the sheet to it.
  ///
  /// Ignored once a screen of the content's navigation stack has been measured here; until then it is
  /// what sizes the sheet, so a stack's first screen can land while the sheet is still arriving.
  func apply(_ reading: AdaptiveSheetReading?) {
    attachToNavigation()
    guard !hasMeasuredScreen, let reading else { return }
    switch reading.source {
    case .layout:
      guard !hasStaticRootReading else { return }
    case .scrollGeometry:
      // A root read as static may be a scrolling root whose scroll view was not built yet.
      break
    }

    measurement = reading.measurement
    isLayoutReading = switch reading.source {
    case .layout: true
    case .scrollGeometry: false
    }
    resize()
  }

  /// Lets a layout reading that fills the sheet size it after all.
  private func releasePlaceholder() {
    guard holdsPlaceholder else { return }
    holdsPlaceholder = false

    guard let sheet, sheet.detents.map(\.identifier) == [Self.detentIdentifier] else { return }
    sheet.animateChanges {
      sheet.invalidateDetents()
    }
  }

  // MARK: - Navigation

  /// Finds the content's navigation controller, and sizes the sheet to its root straight away if the
  /// root does not scroll.
  ///
  /// A scrolling root is SwiftUI's to size until the first push — its reading is right while the sheet
  /// is still arriving. A static root is not: SwiftUI's reading of it is the whole stack's, which fills
  /// the sheet, so it is read here, before the sheet appears, where a resize lands without a jump.
  private func attachToNavigation() {
    guard navigation == nil, let found = Self.navigationController(in: presentedRoot) else { return }

    navigation = found
    measuredScreen = found.topViewController
    startWatchingNavigation()
    if let root = found.topViewController {
      follow(root)
    }
  }

  /// Starts watching as soon as the stack is found — not once the sheet has appeared — so a static
  /// root is measured in the presentation's first frames. SwiftUI's reading of a stack is the stack's
  /// own, which fills the sheet, so waiting for `viewDidAppear` opened every static stack at full height.
  private func startWatchingNavigation() {
    guard displayLink == nil, navigation != nil else { return }

    let link = CADisplayLink(target: self, selector: #selector(checkTopScreen))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  private func stopWatchingNavigation() {
    displayLink?.invalidate()
    displayLink = nil
  }

  /// Measures the screen on top once a push or pop has put a new one there and finished, and keeps
  /// following it while it is there.
  @objc private func checkTopScreen() {
    guard let navigation, navigation.transitionCoordinator == nil,
       let top = navigation.topViewController else { return }

    guard top === measuredScreen else {
      measuredScreen = top
      measure(top)
      return
    }
    follow(top)
  }

  /// Keeps the sheet sized to the screen already on top.
  ///
  /// **A screen that scrolls is followed through its content size; one that does not is re-read here.**
  /// A static screen reports nothing when its height changes, and SwiftUI's reading cannot stand in for
  /// it: taken from outside the stack, it is the stack's, which fills whatever it is given. That is also
  /// how a static root gets sized at all — SwiftUI's reading of it is the full sheet.
  private func follow(_ screen: UIViewController) {
    if let scrollView = Self.firstScrollView(in: screen.view) {
      // Already followed through its content size — or a scrolling root SwiftUI is still sizing.
      // A scroll view that turned up after the screen was first read as static takes over here.
      guard scrollView !== observedScrollView, hasMeasuredScreen else { return }

      measure(screen)
      return
    }

    guard screen.view.window != nil else { return }
    let reading = AdaptiveSheetMeasurement(screenView: screen.view, barHeight: barHeight(over: screen))
    guard reading != measurement else { return }

    measurement = reading
    isLayoutReading = false
    if screen === navigation?.viewControllers.first {
      hasStaticRootReading = true
    }
    // Not for the root: a root read as static may only be a scrolling root whose scroll view SwiftUI
    // has not built yet, and SwiftUI's readings must still reach it then. For a genuinely static root,
    // SwiftUI's reading is the sheet's own height, which this reading has just set.
    if screen !== navigation?.viewControllers.first {
      hasMeasuredScreen = true
    }
    scheduleResize()
  }

  /// How far the navigation bar reaches down the sheet — what a screen's content sits under.
  private var barHeight: CGFloat {
    guard let navigation, !navigation.isNavigationBarHidden else { return 0 }

    let bar = navigation.navigationBar
    return max(0, bar.convert(bar.bounds, to: navigation.view).maxY)
  }

  /// How far the bar reaches over a static screen.
  ///
  /// Before the sheet settles, the bar can still be laid out at its large-title height — 122 where an
  /// inline bar is 70 — while the screen's safe area already has the inline one. The smaller of the two
  /// is the one that will stand, once the safe area has arrived at all.
  private func barHeight(over screen: UIViewController) -> CGFloat {
    let safeAreaTop = screen.view.safeAreaInsets.top
    return safeAreaTop > 0 ? min(barHeight, safeAreaTop) : barHeight
  }

  /// Measures the screen now on top of the stack and resizes the sheet to it.
  private func measure(_ screen: UIViewController) {
    if let scrollView = Self.firstScrollView(in: screen.view) {
      observeContentSize(of: scrollView)
      // Not rendered yet: its content-size observation reports once it is.
      guard scrollView.contentSize.height > 0 else { return }

      measurement = AdaptiveSheetMeasurement(scrollView: scrollView, barHeight: barHeight)
      isLayoutReading = false
      hasMeasuredScreen = true
    } else {
      stopObservingContentSize()
      guard screen.view.window != nil else { return }

      measurement = AdaptiveSheetMeasurement(screenView: screen.view, barHeight: barHeight(over: screen))
      isLayoutReading = false
      hasMeasuredScreen = true
    }

    scheduleResize()
  }

  /// Resizes once the current burst of readings is over.
  ///
  /// A screen that has just been shown reports several content sizes in a row as SwiftUI lays it out —
  /// 132 and then 192 for a three-row screen — and resizing on each drew every step. Waiting for the
  /// main actor's current work to finish sizes the sheet once, to the last of them. Before the sheet
  /// appears there is nothing to see, so it resizes straight away and opens at the latest reading.
  private func scheduleResize() {
    guard hasAppeared else {
      resize()
      return
    }
    guard !isResizeScheduled else { return }

    isResizeScheduled = true
    Task { @MainActor [weak self] in
      await Task.yield()
      guard let self else { return }
      self.isResizeScheduled = false
      self.resize()
    }
  }

  private func observeContentSize(of scrollView: UIScrollView) {
    guard scrollView !== observedScrollView else { return }

    observedScrollView = scrollView
    contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
      // KVO reports on the thread the change was made on, and UIKit lays out on the main thread.
      MainActor.assumeIsolated {
        // Mid-push or mid-pop — or once another screen is on top and not yet measured — the display
        // link measures the screen that settles instead.
        guard let self, let navigation = self.navigation, navigation.transitionCoordinator == nil,
           let top = navigation.topViewController, top === self.measuredScreen else { return }
        self.measure(top)
      }
    }
  }

  private func stopObservingContentSize() {
    contentSizeObservation = nil
    observedScrollView = nil
  }

  /// The first navigation controller among `controller`'s descendants, depth first.
  private static func navigationController(in controller: UIViewController) -> UINavigationController? {
    for child in controller.children {
      if let navigation = child as? UINavigationController {
        return navigation
      }
      if let navigation = navigationController(in: child) {
        return navigation
      }
    }
    return nil
  }

  /// The outermost visible scroll view in `view`'s subtree, breadth first — the one that fills a screen
  /// rather than a carousel nested inside it.
  private static func firstScrollView(in view: UIView) -> UIScrollView? {
    var queue = [view]
    while !queue.isEmpty {
      let candidate = queue.removeFirst()
      if let scrollView = candidate as? UIScrollView, !scrollView.isHidden {
        return scrollView
      }
      queue.append(contentsOf: candidate.subviews)
    }
    return nil
  }

  // MARK: - Detent

  private func resize() {
    // Before the content has reported there is nothing better to say than the height the sheet
    // opened at, and a guess corrected a frame later is a visible jump.
    guard let measurement, let sheet else { return }

    // SwiftUI configures this controller too and can hand back its own detents when its presentation
    // state updates, so ours is re-asserted on every pass rather than installed once.
    let isInstalled = sheet.detents.map(\.identifier) == [Self.detentIdentifier]
    if !isInstalled {
      sheet.detents = [makeDetent()]
      sheet.selectedDetentIdentifier = Self.detentIdentifier
    }

    guard !isInstalled || measurement != appliedMeasurement else { return }
    appliedMeasurement = measurement

    // Sized before it appears, the sheet simply opens at the content's height; only a change that
    // happens on screen is animated.
    if hasAppeared {
      sheet.animateChanges {
        sheet.invalidateDetents()
      }
    } else {
      sheet.invalidateDetents()
    }
  }

  private func makeDetent() -> UISheetPresentationController.Detent {
    .custom(identifier: Self.detentIdentifier) { [weak self] context in
      // A custom detent's height leaves out the bottom safe area, which is why the measurement
      // has already taken the home indicator's inset out.
      guard let self, let measurement = self.measurement else { return context.maximumDetentValue }
      let height = measurement.detentHeight(
        cappedAt: context.maximumDetentValue,
        displayScale: context.containerTraitCollection.displayScale
      )
      // A layout reading that fills the sheet is, until the placeholder is released, a stack not
      // built yet rather than content asking for the whole screen.
      let isFillingLayout = self.holdsPlaceholder && self.isLayoutReading && height >= context.maximumDetentValue
      let resolved = isFillingLayout ? context.maximumDetentValue * .placeholderFraction : height
      return resolved
    }
  }
}

private extension CGFloat {
  /// How much of the screen a sheet whose content is not measurable yet opens at — low enough that
  /// growing to the content reads as the sheet arriving, not as a correction.
  static let placeholderFraction: CGFloat = 0.3
}
#endif
