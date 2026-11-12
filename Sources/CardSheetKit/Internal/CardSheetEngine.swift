#if os(iOS)
import ObjectiveC
import SwiftUI
import UIKit

/// Moves the cards. SwiftUI draws them from `frame(for:)` and friends; everything that moves them
/// lives here, in UIKit terms, because it has to work the content's own scroll view.
///
/// **One distance for everything a vertical drag does.** Below 0 the current card is pulled down
/// to be dismissed — alone, its neighbours staying put. From 0 the card rises from its resting
/// detent, through any larger ones, to the top: full screen, or the largest detent if it may not
/// expand further. Beyond, the content scrolls. A drag travels along it without lifting, and the
/// content never moves until the card is at the top (unless `presentationContentInteraction`
/// says the content scrolls first).
///
/// **Who drives.** The card's pan, except where the content's scroll view scrolls natively — at
/// the top, or always with `.scrolls`; the pan runs beside it there and takes over when a drag
/// down reaches the top of the content. Sideways, at rest, the pan pages between cards.
///
/// **Released**, everything is stepped by hand frame by frame from the release position at the
/// finger's speed: a UIKit animation renders its first frame where it starts and only
/// approximates the finger's velocity, which showed as a frozen frame then a jump.
@MainActor
@Observable
final class CardSheetEngine {
  // MARK: What the cards are drawn from

  private(set) var size: CGSize = .zero
  private(set) var safeArea: UIEdgeInsets = .zero
  private(set) var displayCornerRadius: CGFloat = 0
  /// The top of the cards (the current one also moves down by `dismissOffset`).
  private(set) var cardTop: CGFloat = 0
  private(set) var dismissOffset: CGFloat = 0
  /// Which page is centred, continuously: 1.5 is half way from the second card to the third.
  private(set) var pagePosition: CGFloat = 0
  private(set) var currentIndex = 0
  /// How far the current card's content is scrolled past its top, for tests.
  private(set) var contentScrolled: CGFloat = 0
  private(set) var isDismissing = false
  private(set) var isAttached = false
  private(set) var configuration = SheetConfiguration()
  var options = CardSheetOptions()

  @ObservationIgnored var pageCount = 1
  @ObservationIgnored var onDismiss: () -> Void = {}
  @ObservationIgnored var onPageChange: (Int) -> Void = { _ in }

  // MARK: Derived geometry

  /// The card's lowest resting place — its smallest detent.
  var restTop: CGFloat { configuration.detentTops.max() ?? safeArea.top }
  /// The highest the card goes: the top of the display, or its largest detent.
  var fullTop: CGFloat {
    expandsToFullScreen ? 0 : (configuration.detentTops.min() ?? safeArea.top)
  }

  /// Only a card that can reach `.large` goes on to full screen — a `.large` detent, or a custom
  /// one that resolves to the same height. Below it the largest detent is as high as it goes; and
  /// `presentationExpandsToFullScreen(false)` keeps even a large one from going further.
  private var expandsToFullScreen: Bool {
    guard options.expandsToFullScreen ?? true else { return false }
    guard let highest = configuration.detentTops.min() else { return true }
    return highest <= safeArea.top + 0.5
  }
  /// How far the card rises from its resting detent to its top — none with a single detent
  /// that does not go full screen. (Once kept at 1 pt or more to divide by: a scroll then lifted
  /// the card that point, which read as fully expanded and dropped the neighbours' room, and the
  /// card widened by 24 pt.)
  private var travel: CGFloat { max(restTop - fullTop, 0) }

  /// 0 at the resting detent, 1 at the top; a card with nowhere to rise stays at 0.
  var expansion: CGFloat {
    guard travel > 0 else { return 0 }
    return min(max((restTop - cardTop) / travel, 0), 1)
  }
  private var isAtTop: Bool { cardTop <= fullTop + 0.5 && dismissOffset == 0 }
  /// Filling the whole display — not merely at the largest detent.
  private var isFullScreen: Bool { cardTop <= 0.5 && dismissOffset == 0 }

  private var peek: CGFloat { pageCount > 1 ? (options.neighbourPeek ?? 10) : 0 }
  private var peekInset: CGFloat { peek > 0 ? (peek + 10) * (1 - peekProgress) : 0 }
  private var gap: CGFloat { peek > 0 ? 10 * (1 - peekProgress) : 0 }

  /// How far the neighbours' room is used up: none from the resting detent up to `.large`, so
  /// the neighbouring cards show at every detent, then all of it between `.large` and full
  /// screen, the only stretch where the card has to grow to the display's width. A card that
  /// never goes full screen keeps it all.
  private var peekProgress: CGFloat {
    guard expandsToFullScreen else { return 0 }
    let start = min(restTop, safeArea.top)
    let range = start - fullTop
    guard range > 0 else { return 0 }
    return min(max((start - cardTop) / range, 0), 1)
  }
  /// The card's distance from each side: the neighbours' room, or a floating sheet's inset.
  private var sideInset: CGFloat { max(peekInset, floatingInset * floating) }
  private var pageWidth: CGFloat { size.width - 2 * sideInset + gap }

  /// iOS 26 floats a sheet below its large detent — inset from the sides and the bottom, every
  /// corner rounded, concentric with the display — and attaches it to the edges as it reaches
  /// `.large`. 8 pt: UIKit's own medium sheet, measured before the takeover (and Apple Maps').
  private let floatingInset: CGFloat = 8

  /// 1 at or below the nearest detent smaller than `.large`, 0 at `.large` and above, and
  /// continuous between them, as the system sheet morphs while it is dragged.
  var floating: CGFloat {
    let largeTop = safeArea.top
    guard let nearest = configuration.detentTops.filter({ $0 > largeTop + 1 }).min() else { return 0 }
    return min(max((cardTop - largeTop) / (nearest - largeTop), 0), 1)
  }

  func frame(for index: Int) -> CGRect {
    let x = (CGFloat(index) - pagePosition) * pageWidth + sideInset
    let y = cardTop + (index == currentIndex ? dismissOffset : 0)
    // The card's box; the content inside it is laid out in `contentHeight`, and
    // `visibleHeight` says how much of the card shows.
    return CGRect(x: x, y: y, width: max(size.width - 2 * sideInset, 0), height: size.height)
  }

  /// How much of a card shows. Floating, it ends `floatingInset` above the bottom of the
  /// display; attached, it runs past the bottom by its corner radius, so its bottom corners are
  /// never seen.
  var visibleHeight: CGFloat {
    max(size.height - cardTop - floatingInset * floating + (1 - floating) * bottomCornerRadius, 0)
  }

  /// The height the content is laid out in — the space the card offers, as a sheet resizes its
  /// view controller to its detent: from the card's top to the bottom of the display, or to the
  /// floating gap above it. Pulled down to be dismissed the card slides, it does not shrink.
  var contentHeight: CGFloat {
    max(size.height - cardTop - floatingInset * floating, 0)
  }

  /// The home indicator's inset, less what the floating gap already clears.
  var contentBottomInset: CGFloat {
    max(safeArea.bottom - floatingInset * floating, 0)
  }

  /// The current card's lowest visible point, for tests.
  var visibleBottom: CGFloat { cardTop + dismissOffset + visibleHeight }

  var cornerRadius: CGFloat {
    let resting = configuration.cornerRadius ?? 38
    return resting + (displayCornerRadius - resting) * expansion
  }

  /// Concentric with the display's corners, at the floating inset.
  var bottomCornerRadius: CGFloat { max(displayCornerRadius - floatingInset, 0) }

  /// `presentationDragIndicator` decides, at every height but full screen — where it would sit
  /// under the Dynamic Island. It fades over the last points to the top rather than popping.
  var grabberOpacity: CGFloat {
    guard configuration.showsGrabber else { return 0 }
    guard expandsToFullScreen else { return 1 }
    return min(max((cardTop + dismissOffset) / 24, 0), 1)
  }

  func opacity(for index: Int) -> CGFloat {
    guard isDismissing, index != currentIndex else { return 1 }
    let travel = max(size.height - restTop - dismissCommitOffset, 1)
    return 1 - min(max((dismissOffset - dismissCommitOffset) / travel, 0), 1)
  }

  /// The presenter's dimming: gone at or below the undimmed detent, fading as a card is pulled
  /// away to be dismissed.
  private var dimming: CGFloat {
    var level: CGFloat = 1
    if let undimmed = configuration.undimmedTop {
      level = min(max((undimmed - cardTop) / 40, 0), 1)
    }
    let away = min(dismissOffset / max(size.height - restTop, 1), 1)
    return level * (1 - away)
  }

  private var isInteractiveDismissDisabled: Bool { host?.isModalInPresentation ?? false }

  // MARK: UIKit

  @ObservationIgnored private weak var host: UIViewController?
  @ObservationIgnored private weak var sheet: UISheetPresentationController?
  @ObservationIgnored private var takeover: SheetTakeover?
  @ObservationIgnored private let cardPan = UIPanGestureRecognizer()
  @ObservationIgnored private let backgroundTap = UITapGestureRecognizer()
  @ObservationIgnored private var gestures: GestureDelegate?
  /// The content scroll view under the finger, if the drag started on one.
  @ObservationIgnored private weak var content: UIScrollView?
  @ObservationIgnored private var touchedHorizontalScrollView = false

  /// Called from inside the sheet's content, once it is in a window: reads what SwiftUI
  /// configured, takes the sheet over, and starts handling touches.
  func attach(from view: UIView) {
    guard !isAttached, let window = view.window else { return }
    var responder: UIResponder? = view
    while let current = responder, (current as? UIViewController)?.presentingViewController == nil {
      responder = current.next
    }
    guard let host = responder as? UIViewController, let sheet = host.sheetPresentationController else {
      PrivateSheetAPI.log.error("card sheet: no presented sheet found")
      return
    }
    self.host = host
    self.sheet = sheet
    size = window.bounds.size
    safeArea = window.safeAreaInsets
    displayCornerRadius = window.screen.displayCornerRadius
    host.view.backgroundColor = .clear
    // No safe area inside the sheet: a moving card overlaps the status bar by a different
    // amount every frame, and SwiftUI turned each into a new top inset for the content's
    // scroll view — the content shifted under the finger. The card adds the home indicator's
    // inset itself; detents are resolved against the window's own safe area.
    (host as? UIHostingController<AnyView>)?.safeAreaRegions = []
    // UIKit's too: the content's UIKit views — a SwiftUI ScrollView is a UIScrollView, a
    // NavigationStack a UINavigationController — would follow it one layout pass behind the
    // card, and nothing could keep the content in step with it. A navigation bar gets the
    // status bar's inset from the engine instead, in the same step as the card's position.
    let windowInsets = window.safeAreaInsets
    host.additionalSafeAreaInsets = UIEdgeInsets(
      top: -windowInsets.top, left: -windowInsets.left,
      bottom: -windowInsets.bottom, right: -windowInsets.right
    )

    takeover = SheetTakeover(
      sheet: sheet, bounds: window.bounds, safeArea: window.safeAreaInsets,
      traits: host.traitCollection
    ) { [weak self] configuration in
      self?.apply(configuration)
    }

    let delegate = GestureDelegate(engine: self)
    gestures = delegate
    cardPan.addTarget(delegate, action: #selector(GestureDelegate.pan(_:)))
    cardPan.delegate = delegate
    backgroundTap.addTarget(delegate, action: #selector(GestureDelegate.tap))
    backgroundTap.delegate = delegate
    host.view.addGestureRecognizer(cardPan)
    host.view.addGestureRecognizer(backgroundTap)
    // The sheet's own pans must not also act under a moving card.
    var ancestor = host.view.superview
    while let view = ancestor {
      for gesture in view.gestureRecognizers ?? [] where gesture is UIPanGestureRecognizer {
        gesture.require(toFail: cardPan)
      }
      ancestor = view.superview
    }
    isAttached = true
    updateDimming()
    // UIKit views inside the content — a navigation bar's margins, above all — were laid out
    // before the takeover changed the sheet's size and safe area, and nothing else asks them
    // again until a touch does: lay them out now.
    DispatchQueue.main.async { [weak host] in
      guard let root = host?.view else { return }
      var stack: [UIView] = [root]
      while let view = stack.popLast() {
        view.setNeedsLayout()
        stack.append(contentsOf: view.subviews)
      }
      root.layoutIfNeeded()
    }
    // The content's navigation controllers appear in a layout pass of their own — later on a
    // device than in the simulator — and must have their margins before that pass reaches the
    // screen: fixed a frame late, a large title visibly slid into place; fixed later still, it
    // touched its card's edge. So the fix runs inside every layout pass of the sheet's view.
    LayoutHook.install(on: host.view) { [weak self] in
      self?.fixNavigationMargins()
      self?.holdContentToLayout()
    }
    fixNavigationMargins()
    host.view.setNeedsLayout()
  }

  func start(pageCount: Int, at index: Int) {
    self.pageCount = max(pageCount, 1)
    currentIndex = min(max(index, 0), self.pageCount - 1)
    pagePosition = CGFloat(currentIndex)
  }

  /// SwiftUI changed a presentation modifier: the card goes to the detent asked for, or stays
  /// within the new range.
  private func apply(_ new: SheetConfiguration) {
    let first = !isAttached
    guard first || new != configuration else { return }
    configuration = new
    if first || new.selectedTop != nil {
      springOrPlace(top: new.selectedTop ?? restTop, animated: !first)
    } else if cardTop > restTop || cardTop < fullTop {
      springOrPlace(top: min(max(cardTop, fullTop), restTop), animated: true)
    }
    updateDimming()
  }

  func layoutDidChange() {
    takeover?.clearChrome()
  }

  /// Every navigation controller in the cards — not only the touched one — gets margins of its
  /// own (see `fixMargins(of:)`). Each is fixed once; a pass that finds nothing new costs a walk
  /// down to the first navigation bar of each card.
  func fixNavigationMargins() {
    guard let root = host?.view else { return }
    var stack: [UIView] = [root]
    while let view = stack.popLast() {
      if let bar = view as? UINavigationBar, let controller = Self.navigationController(of: bar) {
        if !fixedNavigations.contains(controller) {
          Self.fixMargins(of: controller, standard: standardMargin)
          fixedNavigations.add(controller)
        }
        continue
      }
      stack.append(contentsOf: view.subviews)
    }
  }
  @ObservationIgnored private let fixedNavigations = NSHashTable<UINavigationController>.weakObjects()

  // MARK: Position

  /// Where the content is at its top. Frozen once the card is at the top: a navigation bar
  /// collapsing its large title shrinks the inset by 52 pt, which must not move the content (UIKit
  /// keeps the offset), and scrolling back must return to the large title's top, where UIKit
  /// expands it again — not stop at the inline bar's.
  private func contentTop(_ scrollView: UIScrollView) -> CGFloat {
    frozenContentTops.object(forKey: scrollView).map { CGFloat($0.doubleValue) } ?? currentContentTop(scrollView)
  }

  /// The content's top with the card where it is now. In a navigation controller: under its
  /// bar, under the safe area the engine gives it — computed, not read, so it is exact in the
  /// very frame the card moves, with no layout pass to wait for. Otherwise the scroll view's
  /// own top, which nothing moves.
  private func currentContentTop(_ scrollView: UIScrollView, top: CGFloat? = nil) -> CGFloat {
    guard let navigation else { return -scrollView.adjustedContentInset.top }
    let safeArea = top.map(navigationSafeArea(at:)) ?? navigationSafeArea
    return -(scrollView.contentInset.top + safeArea + navigation.navigationBar.frame.height)
  }

  /// Where the card's content is laid out now — its navigation controller's view, which spans
  /// the card — as opposed to where the engine has asked for the card to be. SwiftUI moves the
  /// content in its own layout pass, which on a device can come a frame after the engine's
  /// change: a content offset and a bar safe area computed for the new position then met the
  /// old frame for that frame, and everything pinned under the bar, its large title above all,
  /// dipped by however far the card had moved (3–6 pt, measured from an iPhone's screen
  /// recording, where every layer the app could read was in place). Computed from the laid-out
  /// position instead, and again after each layout pass of the sheet, they always match the frame
  /// they are drawn in.
  private var shownTop: CGFloat {
    guard let navigation, let root = host?.view, let view = navigation.viewIfLoaded, view.window != nil else {
      return cardTop + dismissOffset
    }
    return view.convert(view.bounds, to: root).minY
  }

  /// After each layout pass of the sheet — SwiftUI's placement of the cards among it — the
  /// content and its bar follow the card's laid-out position.
  private func holdContentToLayout() {
    guard let content, navigation != nil, !configuration.contentScrollsFirst else { return }
    holdContent(content)
  }

  private func contentBottom(_ scrollView: UIScrollView) -> CGFloat {
    let bottom = scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height
    return max(bottom, contentTop(scrollView))
  }

  /// One frozen top per card's content. A card can be left scrolled — paged away from at a
  /// detent that does not go full screen — and its top must still be there when it comes back:
  /// measured again then, it was measured under a collapsed bar, 52 pt short of the large
  /// title's, and the title could never expand again.
  @ObservationIgnored private let frozenContentTops = NSMapTable<UIScrollView, NSNumber>.weakToStrongObjects()
  @ObservationIgnored private weak var navigation: UINavigationController?
  /// UIKit's top padding for a navigation bar in a sheet (10 pt under the grabber).
  @ObservationIgnored private var navigationPadding: CGFloat = 0

  /// The top safe area the content's navigation controller gets: never less than the padding
  /// UIKit gives the bar at rest (10 pt under the grabber — which it gives only with no safe
  /// area at all, so it must not switch off), and above `.large` exactly as much more as the card
  /// has risen, at the card's laid-out position (`shownTop`). So the bar and its large title hold
  /// still on screen from `.large` all the way to full screen. (With the status bar's height alone, as a system sheet gets, the title rose
  /// with the card for its first 10 pt and then stopped: a small lurch. It now ends 10 pt below
  /// the status bar at full screen instead of at it.)
  private var navigationSafeArea: CGFloat { navigationSafeArea(at: shownTop) }

  private func navigationSafeArea(at top: CGFloat) -> CGFloat {
    let padding = navigationPadding > 0 ? navigationPadding : 10
    return max(safeArea.top + padding - top, padding)
  }

  /// Below 0 pulled towards dismissal, 0 at rest, `travel` at the top with the content at its
  /// top, more as the content scrolls.
  private var position: CGFloat {
    var value = (restTop - cardTop) - dismissOffset
    // Only content scrolled past its top counts: an inset change must never move the card.
    if let content { value += max(content.contentOffset.y - contentTop(content), 0) }
    return value
  }

  private var maximumPosition: CGFloat {
    guard let content else { return travel }
    return travel + contentBottom(content) - contentTop(content)
  }

  private var minimumPosition: CGFloat {
    isInteractiveDismissDisabled ? 0 : -(size.height - restTop)
  }

  /// Past the bottom of the content the drag meets `UIScrollView`'s own resistance curve.
  private func rubberBanded(_ value: CGFloat) -> CGFloat {
    let limit = maximumPosition
    guard value > limit, size.height > 0 else { return value }
    let over = value - limit
    return limit + (1 - 1 / (over * 0.55 / size.height + 1)) * size.height
  }

  private func setPosition(_ value: CGFloat) {
    let clamped = min(max(value, minimumPosition), maximumPosition + size.height / 2)
    if let content {
      content.contentOffset.y = contentTop(content) + max(clamped - travel, 0)
    }
    contentScrolled = max(clamped - travel, 0)
    placeCard(at: min(clamped, travel))
  }

  /// The card's part of a position, at most `travel`.
  private func placeCard(at value: CGFloat) {
    cardTop = restTop - min(max(value, 0), travel)
    dismissOffset = max(-value, 0)
    if let content, !configuration.contentScrollsFirst { holdContent(content) }
    updateDimming()
  }

  /// Below the top the content stays at its own top, and the safe area the engine gives a
  /// navigation bar changes with the card — both in the same step as the card's position, so
  /// they reach the screen in the same frame. At the top, the content's top is frozen for its
  /// scrolling.
  private func holdContent(_ content: UIScrollView) {
    holdNavigationSafeArea()
    let shown = shownTop
    let target = cardTop + dismissOffset
    if cardTop > fullTop + 0.5 {
      // The card has left the top, and every card moves with it.
      frozenContentTops.removeAllObjects()
      content.contentOffset.y = currentContentTop(content)
    } else {
      if frozenContentTops.object(forKey: content) == nil {
        // Frozen at the top's own value, whatever frame is on screen in the meantime.
        let top = currentContentTop(content, top: target)
        frozenContentTops.setObject(NSNumber(value: Double(top)), forKey: content)
        content.contentOffset.y = top + contentScrolled
        awaitingTopLayout = true
      }
      if awaitingTopLayout {
        if abs(shown - target) >= 0.5 {
          // At the top, not laid out there yet: held where the frame on screen needs it.
          content.contentOffset.y = currentContentTop(content)
        } else {
          content.contentOffset.y = contentTop(content) + contentScrolled
          awaitingTopLayout = false
        }
      }
    }
  }
  /// The card reached the top before SwiftUI laid it out there.
  @ObservationIgnored private var awaitingTopLayout = false

  /// The drag down reached the top of the content: from here the card moves. Disabling the
  /// scroll view ends its part of the gesture; the card's pan carries on.
  private func handOverToCard(_ scrollView: UIScrollView) {
    scrollView.isScrollEnabled = false
    let translation = cardPan.translation(in: host?.view).y
    // The content counts as exactly at its top: whatever it overshot is not the card's.
    let cardPart = (restTop - cardTop) - dismissOffset
    drag = .driving(start: cardPart + translation)
    setPosition(cardPart)
  }

  private func updateDimming() {
    sheet?.presenterDimmingView?.alpha = dimming
  }

  private func springOrPlace(top: CGFloat, animated: Bool) {
    let target = restTop - top
    if animated, isAttached {
      start(.spring(.card, target: target, from: restTop - cardTop, velocity: 0, omega: 18))
    } else {
      placeCard(at: target)
    }
  }

  // MARK: Drags

  private enum Drag {
    case none
    /// The card's pan drives the position: `position = start - translation`.
    case driving(start: CGFloat)
    /// The content's scroll view scrolls; the card's pan waits for the top of the content.
    case watching
    /// Sideways at rest: `pagePosition = start - translation / pageWidth`.
    case paging(start: CGFloat)
  }
  @ObservationIgnored private var drag = Drag.none
  /// When the finger last moved. `UIPanGestureRecognizer.velocity` keeps the last movement's
  /// speed while the finger holds still; after a pause the release velocity is zero.
  @ObservationIgnored private var lastMove: (time: CFTimeInterval, translation: CGPoint) = (0, .zero)
  /// Whether the content's scroll view scrolls natively. Only with `.scrolls`: otherwise the
  /// engine drives the content itself, as one continuous distance with the card — SwiftUI's
  /// scroll view cannot be held from outside mid-drag (it ignored `bouncesVertically` and
  /// bounced past its top before the card could take over, then snapped back: a visible jump).
  private var contentScrollsHere: Bool { configuration.contentScrollsFirst }

  /// A finger landed. Returns false above the cards — the background, whose tap dismisses.
  fileprivate func touchBegan(at point: CGPoint, on view: UIView?) -> Bool {
    stopMotion()
    guard point.y >= cardTop + dismissOffset else { return false }
    // The scroll view the finger is on, if any: the nearest one that scrolls vertically.
    touchedHorizontalScrollView = false
    var found: UIScrollView?
    var current = view
    while let candidate = current, candidate !== host?.view {
      if let scrollView = candidate as? UIScrollView {
        if Self.scrollsVertically(scrollView), found == nil { found = scrollView }
        if Self.scrollsHorizontally(scrollView), !Self.scrollsVertically(scrollView) { touchedHorizontalScrollView = true }
      }
      current = candidate.superview
    }
    // Not on it — on a navigation bar, a header: the card's content is still that card's
    // scroll view. A drag there must scroll it back to its top before the card moves, as a drag
    // on the content does; found without it, the card moved alone and the scrolled content
    // snapped to its top — a jump of the whole content.
    content = found ?? cardScrollView(near: view, at: point)
    noteNavigationController()

    // The content's insets are its own — a navigation bar's, the status bar's at full screen.
    content?.isScrollEnabled = contentScrollsHere
    return true
  }

  /// The content's navigation controller, if it is in one — measuring, the first time, the top
  /// padding UIKit gives its bar in a sheet while it has no safe area of its own
  /// (`UINavigationBar._minimumTopPaddingWithTraitCollection:parentView:`).
  private func noteNavigationController() {
    var responder: UIResponder? = content
    while let current = responder, !(current is UINavigationController) { responder = current.next }
    guard let controller = responder as? UINavigationController else {
      navigation = nil
      return
    }
    if controller !== navigation {
      navigationPadding = controller.additionalSafeAreaInsets.top == 0
        ? controller.navigationBar.frame.minY : navigationPadding
    }
    navigation = controller
    Self.fixMargins(of: controller, standard: standardMargin)
    holdNavigationSafeArea()
  }

  private static func navigationController(of bar: UINavigationBar) -> UINavigationController? {
    var responder: UIResponder? = bar
    while let current = responder, !(current is UINavigationController) { responder = current.next }
    return responder as? UINavigationController
  }

  /// A navigation controller in a card keeps margins of its own, the same in every frame,
  /// rather than inheriting them from the views around it. Inherited, they are measured against
  /// the window's margins: a card inset 20 pt from the display's edge got none (its large title
  /// touched the card's edge), and a card moving sideways got a changing amount (the title slid
  /// inside its card while paging).
  ///
  /// Not the controller's `systemMinimumLayoutMargins` either: that is measured against the
  /// display's edge too. A card 3 pt from it (at `.large`, the neighbours' room almost gone) got
  /// a 13 pt minimum, one 20 pt from it (at `.medium`) none — and a margin re-applied on a touch
  /// took whichever was current, so the first touch after the card changed detent moved the
  /// title 3 pt sideways. (iOS 27.0 also reports 0 where 27.2 reports 16.) The sheet's own margin
  /// it is, read once, never under 16 pt — and UIKit is told not to raise it.
  private static func fixMargins(of controller: UINavigationController, standard: CGFloat) {
    let view = controller.view!
    controller.viewRespectsSystemMinimumLayoutMargins = false
    if view.preservesSuperviewLayoutMargins
      || abs(view.directionalLayoutMargins.leading - standard) > 0.1
      || abs(view.directionalLayoutMargins.trailing - standard) > 0.1 {
      view.preservesSuperviewLayoutMargins = false
      view.insetsLayoutMarginsFromSafeArea = false
      view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: standard, bottom: 0, trailing: standard)
    }
  }

  /// The sheet's own margin, as the system sets it on the hosting view, never under 16 pt —
  /// read once, so no card's position can change it.
  private var standardMargin: CGFloat {
    if let cachedStandardMargin { return cachedStandardMargin }
    guard let host else { return 16 }
    let margin = max(host.view.directionalLayoutMargins.leading, 16)
    cachedStandardMargin = margin
    return margin
  }
  @ObservationIgnored private var cachedStandardMargin: CGFloat?

  private func holdNavigationSafeArea() {
    guard let navigation else { return }
    let top = navigationSafeArea
    if abs(navigation.additionalSafeAreaInsets.top - top) > 0.01 {
      navigation.additionalSafeAreaInsets.top = top
    }
  }

  private static func scrollsVertically(_ scrollView: UIScrollView) -> Bool {
    scrollView.contentSize.height > scrollView.bounds.height + 0.5 || scrollView.alwaysBounceVertical
  }

  private static func scrollsHorizontally(_ scrollView: UIScrollView) -> Bool {
    scrollView.contentSize.width > scrollView.bounds.width + 0.5
  }

  /// The content scroll view of the card under `point`, looked for from `view` upwards: the
  /// first ancestor holding a vertically scrolling scroll view whose frame spans the finger's x
  /// — so a neighbouring card's content is never taken for this one's.
  private func cardScrollView(near view: UIView?, at point: CGPoint) -> UIScrollView? {
    guard let root = host?.view else { return nil }
    var ancestor = view?.superview
    while let container = ancestor, container !== root {
      var stack: [UIView] = container.subviews
      var visited = 0
      while let candidate = stack.popLast(), visited < 400 {
        visited += 1
        if let scrollView = candidate as? UIScrollView, Self.scrollsVertically(scrollView) {
          let frame = scrollView.convert(scrollView.bounds, to: root)
          if frame.minX <= point.x, point.x <= frame.maxX { return scrollView }
          continue
        }
        stack.append(contentsOf: candidate.subviews)
      }
      ancestor = container.superview
    }
    return nil
  }

  fileprivate func shouldBeginPan(velocity: CGPoint) -> Bool {
    guard !isDismissing else { return false }
    if abs(velocity.x) > abs(velocity.y) {
      // Sideways belongs to the pager at every height but full screen — or to a carousel
      // in the content.
      return pageCount > 1 && !isFullScreen && dismissOffset == 0 && !touchedHorizontalScrollView
    }
    return true
  }

  fileprivate func isContentPan(_ gesture: UIGestureRecognizer) -> Bool {
    gesture === content?.panGestureRecognizer
  }

  fileprivate func pan(_ pan: UIPanGestureRecognizer) {
    guard let view = host?.view else { return }
    if pan.state == .began {
      // A pan is recognised only once the finger has moved some way (6 pt in the simulator,
      // more under a real finger), and its translation already holds that distance. Counted,
      // the card leapt by it in the drag's first frame — the title jumping on a first touch.
      // As a scroll view does, the drag starts where it is recognised.
      pan.setTranslation(.zero, in: view)
    }
    let translation = pan.translation(in: view)
    if pan.state == .began || hypot(translation.x - lastMove.translation.x, translation.y - lastMove.translation.y) > 0.5 {
      lastMove = (CACurrentMediaTime(), translation)
    }
    switch pan.state {
    case .began:
      stopMotion()
      let velocity = pan.velocity(in: view)
      if abs(velocity.x) > abs(velocity.y) {
        drag = .paging(start: pagePosition)
      } else if contentScrollsHere, let content, content.isScrollEnabled {
        drag = .watching
      } else {
        drag = .driving(start: position)
      }
    case .changed:
      switch drag {
      case .driving(let start):
        // Applied at the next display frame, not here: see `pendingDrag`.
        pendingDrag = rubberBanded(start - translation.y)
        startDragLink()
      case .watching:
        // `.scrolls` only: the content scrolls natively until a drag down reaches its top.
        guard let content else { break }
        if pan.velocity(in: view).y > 0, content.contentOffset.y <= contentTop(content) + 0.5 {
          handOverToCard(content)
        }
      case .paging(let start):
        var page = start - translation.x / max(pageWidth, 1)
        let last = CGFloat(pageCount - 1)
        // Past the first or last card, the pager resists.
        if page < 0 { page *= 0.3 } else if page > last { page = last + (page - last) * 0.3 }
        pagePosition = page
      case .none:
        break
      }
    case .ended, .cancelled, .failed:
      let stillFor = CACurrentMediaTime() - lastMove.time
      let flicked = pan.state == .ended && stillFor < 0.05
      let velocity = flicked ? pan.velocity(in: view) : .zero
      switch drag {
      case .driving(let start):
        // The lift can carry movement of its own; dropped, the release starts behind.
        stopDragLink()
        setPosition(rubberBanded(start - translation.y))
        drag = .none
        release(velocity: -velocity.y)
      case .paging:
        drag = .none
        releasePage(velocity: -velocity.x / max(pageWidth, 1))
      case .watching, .none:
        drag = .none
        settle()
      }
    default:
      break
    }
  }

  fileprivate func backgroundTapped() {
    guard !isDismissing, !isInteractiveDismissDisabled, configuration.undimmedTop.map({ cardTop < $0 }) ?? true else { return }
    stopMotion()
    dismissCard(velocity: 0)
  }

  fileprivate func shouldReceiveBackgroundTap(at point: CGPoint) -> Bool {
    point.y < cardTop + dismissOffset
  }

  // MARK: Release

  private func coastDistance(_ velocity: CGFloat) -> CGFloat {
    let rate = UIScrollView.DecelerationRate.fast.rawValue
    return velocity / 1000 * rate / (1 - rate)
  }

  private var snaps: Bool {
    switch options.snapping ?? .automatic {
    case .always: true
    case .never: false
    case .automatic: configuration.detentTops.count > 1
    }
  }

  /// Where a snapping card can come to rest: each detent, and the top.
  private var restingPositions: [CGFloat] {
    var positions = configuration.detentTops.map { restTop - $0 }.filter { $0 >= 0 && $0 <= travel }
    positions.append(travel)
    positions.append(0)
    return Array(Set(positions)).sorted()
  }

  private func release(velocity: CGFloat) {
    if position > maximumPosition + 0.5 {
      // Pulled past the bottom of the content: back, as a scroll view bounces.
      start(.spring(.position, target: maximumPosition, from: position, velocity: velocity, omega: 18))
    } else if position > travel + 0.5 {
      start(abs(velocity) > 20 ? .momentum(velocity: velocity) : nil)
    } else if position < 0 {
      if position + coastDistance(velocity) < -120 {
        dismissCard(velocity: velocity)
      } else {
        start(.spring(.card, target: 0, from: position, velocity: velocity, omega: 18))
      }
    } else if snaps {
      let landing = position + coastDistance(velocity)
      let target = restingPositions.min { abs($0 - landing) < abs($1 - landing) } ?? 0
      start(.spring(.card, target: target, from: position, velocity: velocity, omega: 18))
    } else {
      start(abs(velocity) > 20 ? .coast(velocity: velocity) : nil)
    }
  }

  @ObservationIgnored private var pendingPage: Int?

  private func releasePage(velocity: CGFloat) {
    let projected = pagePosition + velocity * 0.12
    let nearest = min(max(projected.rounded(), CGFloat(currentIndex - 1)), CGFloat(currentIndex + 1))
    let target = min(max(nearest, 0), CGFloat(pageCount - 1))
    pendingPage = Int(target)
    start(.spring(.page, target: target, from: pagePosition, velocity: velocity, omega: 18))
  }

  private func dismissCard(velocity: CGFloat) {
    isDismissing = true
    dismissCommitOffset = dismissOffset
    // Aimed past the bottom edge, so the card leaves at speed rather than easing into it.
    let target = -(size.height * 1.15 - restTop)
    start(.spring(.card, target: target, from: position, velocity: velocity, omega: 14))
  }
  @ObservationIgnored private var dismissCommitOffset: CGFloat = 0

  private func finishDismissal() {
    stopLink()
    // UIKit takes a few frames to finish a dismissal, even unanimated; nothing of the sheet
    // may show meanwhile.
    host?.view.isHidden = true
    onDismiss()
  }

  // MARK: Motion, frame by frame

  private enum Axis {
    /// The card alone.
    case card
    /// The whole position, content included — a bounce at the bottom of the content.
    case position
    case page
  }

  private enum Motion {
    /// The content's momentum: a scroll view's normal deceleration.
    case momentum(velocity: CGFloat)
    /// Momentum that reached the top of the content: it overshoots and springs back, as a
    /// scroll view bounces — the content alone, the card stays where it is.
    case topBounce(velocity: CGFloat, elapsed: CGFloat)
    /// The card coasting after a flick: fast deceleration, stopping at either end.
    case coast(velocity: CGFloat)
    /// Critically damped, solved exactly: no overshoot, no drift.
    case spring(Axis, target: CGFloat, from: CGFloat, velocity: CGFloat, omega: CGFloat, elapsed: CGFloat = 0)
  }
  @ObservationIgnored private var motion: Motion?
  @ObservationIgnored private var link: CADisplayLink?
  @ObservationIgnored private var lastTick: CFTimeInterval = 0

  private func start(_ newMotion: Motion?) {
    motion = newMotion
    guard newMotion != nil else {
      stopLink()
      settle()
      return
    }
    lastTick = CACurrentMediaTime()
    if link == nil {
      let newLink = CADisplayLink(target: LinkTarget(self), selector: #selector(LinkTarget.tick(_:)))
      newLink.add(to: .main, forMode: .common)
      link = newLink
    }
  }

  fileprivate func tick(_ link: CADisplayLink) {
    guard let current = motion else { return stopLink() }
    let dt = CGFloat(min(max(link.targetTimestamp - lastTick, 0), 1.0 / 20))
    lastTick = link.targetTimestamp
    var finished = false

    switch current {
    case .momentum(var velocity):
      velocity *= pow(UIScrollView.DecelerationRate.normal.rawValue, dt * 1000)
      let next = position + velocity * dt
      if next > maximumPosition, velocity > 0 {
        // Reaching the bottom with speed to spare: overshoot and come back, as a scroll
        // view bounces.
        setPosition(maximumPosition)
        motion = .spring(.position, target: maximumPosition, from: maximumPosition, velocity: velocity, omega: 18)
        return
      }
      if next < travel, velocity < 0, let content, content.contentOffset.y > contentTop(content) - 0.5 {
        // Reaching the top with speed to spare — the finger already lifted: bounce. (With
        // the finger still down, the same drag would bring the card down instead.)
        setPosition(travel)
        motion = .topBounce(velocity: -velocity, elapsed: 0)
        return
      }
      setPosition(max(next, travel))
      finished = abs(velocity) < 10 || next <= travel
      motion = .momentum(velocity: velocity)

    case .topBounce(let velocity, var elapsed):
      // Critically damped from the top at the arriving speed: past the top and back.
      elapsed += dt
      let omega: CGFloat = 14
      let overshoot = velocity * elapsed * exp(-omega * elapsed)
      if let content { content.contentOffset.y = contentTop(content) - overshoot }
      finished = elapsed > 0.1 && overshoot < 0.5
      if finished, let content { content.contentOffset.y = contentTop(content) }
      motion = .topBounce(velocity: velocity, elapsed: elapsed)

    case .coast(var velocity):
      velocity *= pow(UIScrollView.DecelerationRate.fast.rawValue, dt * 1000)
      let next = position + velocity * dt
      let clamped = min(max(next, 0), travel)
      placeCard(at: clamped)
      finished = abs(velocity) < 5 || clamped != next
      motion = .coast(velocity: velocity)

    case .spring(let axis, let target, let from, let velocity, let omega, var elapsed):
      elapsed += dt
      let offset = from - target
      let b = velocity + omega * offset
      let decay = exp(-omega * elapsed)
      let x = target + (offset + b * elapsed) * decay
      let v = (velocity - omega * b * elapsed) * decay
      finished = abs(x - target) < (axis == .page ? 0.002 : 0.5) && abs(v) < (axis == .page ? 0.01 : 5)
      let value = finished ? target : x
      switch axis {
      case .card: placeCard(at: value)
      case .position: setPosition(value)
      case .page: pagePosition = value
      }
      motion = .spring(axis, target: target, from: from, velocity: velocity, omega: omega, elapsed: elapsed)
    }

    if isDismissing {
      // Gone the frame the card's top passes the bottom of the screen.
      if cardTop + dismissOffset >= size.height || finished { finishDismissal() }
    } else if finished {
      motion = nil
      stopLink()
      settle()
    }
  }

  private func stopLink() {
    link?.invalidate()
    link = nil
  }

  /// Where the finger has taken the card, waiting for the next display frame. Applied straight
  /// from the touch callback, it reached the screen in two halves: the safe area UIKit gives the
  /// navigation bar is laid out at once, but SwiftUI moved the card's content a frame later —
  /// so for one frame the bar sat on the new safe area over the old card position, and the large
  /// title dipped by however far the finger had moved (12–23 px, measured on an iPhone at 120
  /// Hz). Release motions never did it: they step from a display link, where every part lands in
  /// the same frame. Drags now apply from one too.
  @ObservationIgnored private var pendingDrag: CGFloat?
  @ObservationIgnored private var dragLink: CADisplayLink?

  private func startDragLink() {
    guard dragLink == nil else { return }
    let newLink = CADisplayLink(target: LinkTarget(self), selector: #selector(LinkTarget.dragTick(_:)))
    newLink.add(to: .main, forMode: .common)
    dragLink = newLink
  }

  private func stopDragLink() {
    dragLink?.invalidate()
    dragLink = nil
    pendingDrag = nil
  }

  fileprivate func dragTick() {
    guard let value = pendingDrag else { return }
    pendingDrag = nil
    setPosition(value)
  }

  /// A touch stops whatever is moving, where it is, as a scroll view stops under a finger.
  private func stopMotion() {
    guard !isDismissing, motion != nil else { return }
    if case .spring(.page, let target, _, _, _, _) = motion {
      pagePosition = target
    }
    if case .topBounce = motion, let content {
      content.contentOffset.y = contentTop(content)
    }
    motion = nil
    stopLink()
    settle()
  }

  /// Wherever things came to rest: the content scrolls natively only at the top (or always,
  /// with `.scrolls`), and a finished page change is reported.
  private func settle() {
    guard motion == nil, !isDismissing else { return }
    if let page = pendingPage {
      pendingPage = nil
      pagePosition = CGFloat(page)
      if page != currentIndex {
        currentIndex = page
        onPageChange(page)
      }
    }
    content?.isScrollEnabled = contentScrollsHere
  }
}

/// UIKit's gesture callbacks, kept off the observable engine.
@MainActor
private final class GestureDelegate: NSObject, UIGestureRecognizerDelegate {
  weak var engine: CardSheetEngine?
  init(engine: CardSheetEngine) { self.engine = engine }

  @objc func pan(_ gesture: UIPanGestureRecognizer) { engine?.pan(gesture) }
  @objc func tap() { engine?.backgroundTapped() }

  func gestureRecognizer(_ gesture: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    guard let engine, let view = gesture.view else { return false }
    let point = touch.location(in: view)
    if gesture is UITapGestureRecognizer { return engine.shouldReceiveBackgroundTap(at: point) }
    return engine.touchBegan(at: point, on: touch.view)
  }

  func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
    guard let engine, let pan = gesture as? UIPanGestureRecognizer else { return true }
    return engine.shouldBeginPan(velocity: pan.velocity(in: pan.view))
  }

  func gestureRecognizer(
    _ gesture: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
  ) -> Bool {
    // The card's pan watches the content's own pan rather than replacing it.
    gesture is UIPanGestureRecognizer && (engine?.isContentPan(other) ?? false)
  }
}

/// Runs `afterLayout` at the end of every `layoutSubviews` of one view, by giving that instance a
/// runtime subclass of its own class. A layout pass lays a view out before its subviews, so what
/// it changes in them lands in the same pass — before the frame reaches the screen.
@MainActor
enum LayoutHook {
  private static var callbackKey: UInt8 = 0

  private final class Callback: NSObject {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
  }

  static func install(on view: UIView, afterLayout: @escaping () -> Void) {
    objc_setAssociatedObject(view, &callbackKey, Callback(afterLayout), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    guard let original = object_getClass(view) else { return }
    let originalName = NSStringFromClass(original)
    if originalName.hasPrefix("CardSheetKitLayoutHook_") { return }
    let name = "CardSheetKitLayoutHook_" + originalName
    let subclass: AnyClass
    if let existing = NSClassFromString(name) {
      subclass = existing
    } else {
      guard let created = objc_allocateClassPair(original, name, 0) else { return }
      let selector = #selector(UIView.layoutSubviews)
      guard let method = class_getInstanceMethod(original, selector) else { return }
      typealias Layout = @convention(c) (AnyObject, Selector) -> Void
      let superIMP = unsafeBitCast(method_getImplementation(method), to: Layout.self)
      let block: @convention(block) (AnyObject) -> Void = { view in
        superIMP(view, selector)
        MainActor.assumeIsolated {
          (objc_getAssociatedObject(view, &callbackKey) as? Callback)?.run()
        }
      }
      class_addMethod(created, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
      objc_registerClassPair(created)
      subclass = created
    }
    object_setClass(view, subclass)
  }
}

/// `CADisplayLink` retains its target; this keeps the engine free to go.
@MainActor
private final class LinkTarget: NSObject {
  weak var engine: CardSheetEngine?
  init(_ engine: CardSheetEngine) { self.engine = engine }
  @objc func tick(_ link: CADisplayLink) {
    guard let engine else { return link.invalidate() }
    engine.tick(link)
  }
  @objc func dragTick(_ link: CADisplayLink) {
    guard let engine else { return link.invalidate() }
    engine.dragTick()
  }
}
#endif
