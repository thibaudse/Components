import XCTest

/// Drives the real gestures and keeps a screenshot of each state, so the sheet's behaviour can be
/// checked without anyone holding the phone. Screenshots land in the test result bundle.
@MainActor
final class SheetWalkthroughTests: XCTestCase {
  private var app: XCUIApplication!
  /// `.large`: the card rests under the status bar (62 pt on an iPhone 17 or 18 Pro), or 8 pt
  /// down a display with no status bar across its top (an iPhone Duo). The sheet reports it.
  private var restingTop: CGFloat { CGFloat(state("large")) }

  /// Every iPhone but the Duo, which puts its status bar down the side.
  private var hasStatusBarAcrossTop: Bool { restingTop >= 40 }

  /// Between `.large` and full screen the card stays wherever it is let go — 62 pt of room under
  /// a status bar across the top, but only 8 pt on an iPhone Duo, less than XCUITest loses from
  /// the start of every drag. Tests that land a release in that stretch need the room.
  private func requireRoomAboveLarge() throws {
    try XCTSkipUnless(hasStatusBarAcrossTop, "only \(Int(restingTop)) pt between .large and full screen on this display")
  }

  override func setUp() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = Self.arguments([])
    app.launch()
  }

  /// Every lab option on the command line, the defaults unless overridden: a value someone left
  /// in the simulator's settings must not change what a test runs against.
  nonisolated private static func arguments(_ overrides: [String]) -> [String] {
    var options = ["detents": "large", "snaps": "NO", "peeksNeighbours": "YES", "dismissible": "YES", "wrapsInNavigation": "YES"]
    for pair in stride(from: 0, to: overrides.count - 1, by: 2) {
      options[String(overrides[pair].dropFirst())] = overrides[pair + 1]
    }
    return options.sorted { $0.key < $1.key }.flatMap { ["-\($0.key)", $0.value] }
  }

  func testWalkthrough() {
    app.buttons["row.0"].tap()
    XCTAssertTrue(app.scrollViews["card.0"].waitForExistence(timeout: 5))
    settle()
    snapshot("1-presented")
    XCTAssertEqual(top(of: 0), restingTop, accuracy: 2, "the card rests at its detent")

    app.scrollViews["card.0"].swipeLeft()
    XCTAssertTrue(app.scrollViews["card.1"].waitForExistence(timeout: 3))
    settle()
    XCTAssertEqual(page(), 1)
    snapshot("2-paged")

    // A short drag, held still before release: the card stays where the finger stopped.
    let hasRoomAboveLarge = hasStatusBarAcrossTop
    if hasRoomAboveLarge {
      drag(card: 1, by: -50)
      settle()
      snapshot("3-between")
      let between = top(of: 1)
      XCTAssertTrue((20...80).contains(between), "the card stays between resting and full (top \(between))")
      settle()
      XCTAssertEqual(top(of: 1), between, accuracy: 0.5, "and does not drift to either end")
    }

    // A drag from there carries the card to full screen and goes straight on into the content.
    drag(card: 1, by: -250)
    settle()
    snapshot("4-full-and-scrolled")
    XCTAssertEqual(top(of: 1), 0, accuracy: 1, "the drag took the card full screen")
    XCTAssertGreaterThan(state("scroll"), 20, "and kept going into the content")

    // Full screen, a new drag scrolls the content natively.
    drag(card: 1, by: -200)
    settle()
    snapshot("5-scrolled")
    XCTAssertEqual(top(of: 1), 0, accuracy: 1)

    // Flung back to the top — the finger lifted first — the content bounces; the card stays.
    // Each flick shorter than what is left to scroll, so the finger lifts before the top.
    for _ in 0..<8 where state("scroll") > 0 {
      flick(card: 1, by: min(70, max(CGFloat(state("scroll")) - 10, 15)))
      settle()
    }
    snapshot("6-flung-to-top")
    XCTAssertLessThanOrEqual(state("scroll"), 1, "the content is back at its top")
    XCTAssertEqual(top(of: 1), 0, accuracy: 1, "a fling to the top does not bring the card down")

    // At the top, a drag down brings the card down with the finger.
    if hasRoomAboveLarge {
      drag(card: 1, by: 40)
      settle()
      snapshot("7-coming-down")
      XCTAssertGreaterThan(top(of: 1), 10, "the card came down")
      XCTAssertLessThan(top(of: 1), restingTop, "and stayed where the finger left it")
    }

    // A short pull past rest springs back.
    drag(card: 1, by: 90)
    settle()
    snapshot("8-collapsed")
    XCTAssertEqual(top(of: 1), restingTop, accuracy: 2, "a pull brings the card to rest")

    app.scrollViews["card.1"].swipeDown(velocity: .fast)
    settle()
    snapshot("9-dismissed")
    XCTAssertFalse(app.otherElements["cardSheet"].exists, "a pull at rest dismisses the sheet")
  }

  /// One drag from rest, never lifted: the card to full screen, then the content.
  func testOneDragFromRestScrollsOnceFull() {
    app.buttons["row.2"].tap()
    XCTAssertTrue(app.scrollViews["card.2"].waitForExistence(timeout: 5))
    settle()

    drag(card: 2, by: -620)
    settle()
    snapshot("long-drag")
    XCTAssertEqual(top(of: 2), 0, accuracy: 1, "the drag took the card full screen")
    XCTAssertGreaterThan(state("scroll"), 20, "and went on scrolling the content")
  }

  /// A flick from rest: the card to full screen, the content carried on by momentum.
  func testFlickFromRest() {
    app.buttons["row.3"].tap()
    XCTAssertTrue(app.scrollViews["card.3"].waitForExistence(timeout: 5))
    settle()

    app.scrollViews["card.3"].swipeUp(velocity: .fast)
    settle()
    snapshot("flick")
    XCTAssertEqual(top(of: 3), 0, accuracy: 1, "the flick took the card full screen")
    XCTAssertGreaterThan(state("scroll"), 20, "and the content kept moving")
  }

  /// With snapping on, a release between the two ends springs to the nearer one.
  func testSnapping() throws {
    app.terminate()
    app.launchArguments = Self.arguments(["-snaps", "YES"])
    app.launch()
    app.buttons["row.0"].tap()
    XCTAssertTrue(app.scrollViews["card.0"].waitForExistence(timeout: 5))
    settle()
    try requireRoomAboveLarge()

    drag(card: 0, by: -30)
    settle()
    snapshot("snap-back")
    XCTAssertEqual(top(of: 0), restingTop, accuracy: 2, "under half way, the card springs back to rest")

    drag(card: 0, by: -70)
    settle()
    snapshot("snap-full")
    XCTAssertEqual(top(of: 0), 0, accuracy: 1, "past half way, it springs to full screen")
    XCTAssertLessThanOrEqual(state("scroll"), 1, "without scrolling the content")
  }

  /// Pulled down a little at rest and let go: only a short way, so the card springs back.
  func testShortPullSpringsBack() {
    app.buttons["row.1"].tap()
    XCTAssertTrue(app.scrollViews["card.1"].waitForExistence(timeout: 5))
    settle()

    drag(card: 1, by: 80)
    settle()
    snapshot("pull-back")
    XCTAssertTrue(app.otherElements["cardSheet"].exists, "a short pull does not dismiss")
    XCTAssertEqual(top(of: 1), restingTop, accuracy: 2, "the card springs back to rest")
  }

  /// A tap on the dimmed background above the card dismisses.
  func testTapOnBackgroundDismisses() {
    app.buttons["row.0"].tap()
    XCTAssertTrue(app.scrollViews["card.0"].waitForExistence(timeout: 5))
    settle()
    if !hasStatusBarAcrossTop {
      // An iPhone Duo leaves 8 pt above a `.large` card, at the display's very edge: the
      // background is tapped above a `.medium` one instead.
      app.terminate()
      app.launchArguments = Self.arguments(["-detents", "medium"])
      app.launch()
      app.buttons["row.0"].tap()
      XCTAssertTrue(app.scrollViews["card.0"].waitForExistence(timeout: 5))
      settle()
    }

    // Just above the card.
    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 120, dy: top(of: 0) - 2)).tap()
    settle()
    snapshot("tapped-background")
    XCTAssertFalse(app.otherElements["cardSheet"].exists, "a tap on the background dismisses")
  }

  /// A tap on the card itself does not.
  func testTapOnCardKeepsTheSheet() {
    app.buttons["row.0"].tap()
    XCTAssertTrue(app.scrollViews["card.0"].waitForExistence(timeout: 5))
    settle()

    app.scrollViews["card.0"].tap()
    settle()
    XCTAssertTrue(app.otherElements["cardSheet"].exists, "a tap on the card keeps the sheet")
  }

  /// One drag from scrolled full-screen content: back to the top, the card to rest, and away.
  func testOneDragFromFullScreenDismisses() {
    app.buttons["row.1"].tap()
    XCTAssertTrue(app.scrollViews["card.1"].waitForExistence(timeout: 5))
    settle()
    drag(card: 1, by: -260)
    settle()
    XCTAssertEqual(top(of: 1), 0, accuracy: 1)
    XCTAssertGreaterThan(state("scroll"), 20, "the content is scrolled")

    drag(card: 1, by: 640)
    settle()
    snapshot("dismissed-in-one-drag")
    XCTAssertFalse(app.otherElements["cardSheet"].exists, "the one drag went all the way to dismissal")
  }

  /// A short, fast flick from rest: the card keeps going after the finger lifts.
  func testShortFlickCoasts() throws {
    app.buttons["row.4"].tap()
    XCTAssertTrue(app.scrollViews["card.4"].waitForExistence(timeout: 5))
    settle()
    try requireRoomAboveLarge()

    let frame = app.scrollViews["card.4"].frame
    let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: app.windows.firstMatch.frame.height - 274))
    start.press(forDuration: 0.02, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -30)),
          withVelocity: 900, thenHoldForDuration: 0)
    settle()
    snapshot("short-flick")
    XCTAssertLessThan(top(of: 4), restingTop - 30, "the card coasted past where the finger lifted")
    XCTAssertLessThanOrEqual(state("scroll"), 1, "coasting never scrolls the content")
  }

    /// With `.medium` and `.large`, the cards page at both detents — only full screen stops it.
  func testPagingAtEveryDetentButFullScreen() {
    app.terminate()
    app.launchArguments = Self.arguments(["-detents", "mediumAndLarge"])
    app.launch()
    app.buttons["row.1"].tap()
    XCTAssertTrue(app.scrollViews["card.1"].waitForExistence(timeout: 5))
    settle()
    let medium = top(of: 1)
    XCTAssertGreaterThan(medium, app.windows.firstMatch.frame.height / 3, "the card rests at .medium")
    snapshot("floating-at-medium")
    XCTAssertEqual(bottom(), app.windows.firstMatch.frame.height - 8, accuracy: 1, "at .medium the card floats 8 pt above the bottom")

    // Up to .large (two detents: it snaps).
    drag(card: 1, by: -200)
    settle()
    XCTAssertEqual(top(of: 1), restingTop, accuracy: 2, "the card snapped to .large")
    XCTAssertGreaterThan(bottom(), app.windows.firstMatch.frame.height, "at .large it is attached to the bottom")
    XCTAssertEqual(grabber(), 1, "presentationDragIndicator(.visible): the grabber shows at .large too")

    app.scrollViews["card.1"].swipeLeft()
    settle()
    snapshot("paged-at-large")
    XCTAssertEqual(page(), 2, "at .large the cards page sideways")

    // On to full screen, where paging stops.
    drag(card: 2, by: -60)
    settle()
    XCTAssertEqual(top(of: 2), 0, accuracy: 1, "the card went full screen")
    XCTAssertEqual(grabber(), 0, "full screen, the grabber is gone")
    app.scrollViews["card.2"].swipeLeft()
    settle()
    XCTAssertEqual(page(), 2, "full screen, a sideways swipe does not page")
  }

  /// Content in a NavigationStack is laid out right from the first frame, not after a touch.
  func testNavigationStackLaidOutBeforeTouch() {
    app.terminate()
    app.launchArguments = Self.arguments(["-detents", "mediumAndLarge"])
    app.launch()
    app.buttons["row.2"].tap()
    XCTAssertTrue(app.scrollViews["card.2"].waitForExistence(timeout: 5))
    settle()
    snapshot("nav-before-touch")
    let title = app.navigationBars.staticTexts["Card 3"].firstMatch
    XCTAssertTrue(title.exists, "the content's navigation bar shows its title")
    let before = title.frame
    app.scrollViews["card.2"].tap()
    settle()
    snapshot("nav-after-touch")
    XCTAssertEqual(title.frame, before, "a touch does not move the navigation bar's title")
    XCTAssertGreaterThan(title.frame.minX, 30, "the large title keeps its margin inside the card")
  }

    /// A NavigationStack's bar at full screen with the content scrolled under it.
  func testNavigationBarWhenScrolledFullScreen() {
    app.buttons["row.2"].tap()
    XCTAssertTrue(app.scrollViews["card.2"].waitForExistence(timeout: 5))
    settle()
    snapshot("navbar-rest")
    let bar = app.navigationBars.firstMatch
    XCTAssertTrue(bar.exists)

    drag(card: 2, by: -300)
    settle()
    snapshot("navbar-scrolled-full")
    XCTAssertEqual(top(of: 2), 0, accuracy: 1, "the card is full screen")
    // Under the status bar — or, with none across the top (an iPhone Duo), where the bar sat at
    // `.large`: 16 pt of UIKit's padding under the card's 8 pt top.
    let statusBarBottom: CGFloat = hasStatusBarAcrossTop ? restingTop : restingTop + 16
    XCTAssertEqual(bar.frame.minY, statusBarBottom, accuracy: 1, "full screen, the bar sits below the status bar")
    let fixed = bar.frame

    drag(card: 2, by: -300)
    settle()
    snapshot("navbar-scrolled-more")
    XCTAssertEqual(bar.frame, fixed, "the bar stays fixed while the content scrolls under it")

    drag(card: 2, by: 200)
    settle()
    XCTAssertEqual(bar.frame.minY, statusBarBottom, accuracy: 1, "scrolling back, it is still fixed")
    XCTAssertLessThan(titleHeight(), 30, "scrolled, the title is inline")

    // Flung back to the top, the finger already lifted: the content bounces there, the card
    // stays full screen, and the large title is back.
    for _ in 0..<8 where state("scroll") > 0 {
      flick(card: 2, by: 70)
      settle()
    }
    snapshot("navbar-back-at-top")
    XCTAssertEqual(top(of: 2), 0, accuracy: 1, "a fling to the top bounces; it does not bring the card down")
    XCTAssertGreaterThan(titleHeight(), 30, "at the top, the large title is back")
  }

  /// Plain content (no NavigationStack) at full screen scrolls under the status bar, no blur.
  func testPlainContentFullScreen() {
    app.terminate()
    app.launchArguments = Self.arguments(["-wrapsInNavigation", "NO"])
    app.launch()
    app.buttons["row.2"].tap()
    XCTAssertTrue(app.scrollViews["card.2"].waitForExistence(timeout: 5))
    settle()
    drag(card: 2, by: -300)
    settle()
    snapshot("plain-scrolled-full")
    XCTAssertEqual(top(of: 2), 0, accuracy: 1, "the card is full screen")
    XCTAssertFalse(app.staticTexts["card.title.2"].isHittable, "the content scrolled")
  }

    /// Full screen with the large title, then a slow drag down to `.large`.
  func testLargeTitleFullScreenToLarge() {
    app.buttons["row.2"].tap()
    XCTAssertTrue(app.scrollViews["card.2"].waitForExistence(timeout: 5))
    settle()
    // From `.large` to the top, and the 16 pt or so XCUITest loses at the start of a drag.
    drag(card: 2, by: -(restingTop + 23))
    settle()
    XCTAssertEqual(top(of: 2), 0, accuracy: 1)
    XCTAssertLessThan(state("scroll"), 10, "full screen, the content (about) at its top")
    let frame = app.scrollViews["card.2"].frame
    let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: 400))
    start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 90)), withVelocity: 600, thenHoldForDuration: 0.3)
    settle()
    XCTAssertEqual(top(of: 2), restingTop, accuracy: 2, "the card came back down to .large")
    XCTAssertGreaterThan(titleHeight(), 30, "with its large title")
  }

    /// At `.medium` the content is laid out in the card's space, as a sheet resizes its view
  /// controller — not at the display's full height with its bottom off screen.
  func testContentFitsTheMediumDetent() {
    app.terminate()
    app.launchArguments = Self.arguments(["-detents", "mediumAndLarge"])
    app.launch()
    app.buttons["row.1"].tap()
    XCTAssertTrue(app.scrollViews["card.1"].waitForExistence(timeout: 5))
    settle()
    snapshot("content-at-medium")
    let content = app.scrollViews["card.1"].frame
    XCTAssertEqual(content.minY, top(of: 1), accuracy: 1, "the content starts at the card's top")
    XCTAssertEqual(content.maxY, CGFloat(state("bottom")), accuracy: 1, "and ends where the card ends")
    XCTAssertEqual(content.maxY, app.windows.firstMatch.frame.height - 8, accuracy: 1, "8 pt above the display's bottom")

    // The large title keeps the standard margin inside its card — before any touch, and the
    // same margin after paging, whatever the card's position on screen.
    let margin = largeTitleMargin(card: 1)
    XCTAssertGreaterThan(margin, 14, "the large title does not touch the card's edge (\(margin))")
    let frame = app.scrollViews["card.1"].frame
    let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.maxX - 40, dy: frame.minY + 200))
    start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -260, dy: 0)), withVelocity: 500, thenHoldForDuration: 0.1)
    settle()
    XCTAssertEqual(page(), 2)
    XCTAssertEqual(largeTitleMargin(card: 2), margin, accuracy: 0.5, "paging does not move the title inside its card")
  }

  /// At its largest detent short of full screen, the content scrolls in place: its large title
  /// collapses into the bar, and comes back when the content returns to its top.
  func testLargeTitleReturnsAtMedium() {
    app.terminate()
    app.launchArguments = Self.arguments(["-detents", "medium", "-snaps", "NO"])
    app.launch()
    app.buttons["row.1"].tap()
    XCTAssertTrue(app.scrollViews["card.1"].waitForExistence(timeout: 5))
    settle()
    let medium = top(of: 1)
    let left = state("left")
    XCTAssertGreaterThan(titleHeight(), 30, "the card opens with its large title")
    drag(card: 1, by: -200)
    settle()
    XCTAssertGreaterThan(state("scroll"), 100, "the content scrolled")
    XCTAssertEqual(top(of: 1), medium, accuracy: 0.5, "the card did not move")
    XCTAssertEqual(state("left"), left, "nor change its width")
    XCTAssertLessThan(titleHeight(), 30, "and the title went into the bar")
    // To the next card and back, as in the report: the scrolled card's top must survive it.
    let frame = app.scrollViews["card.1"].frame
    let side = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.maxX - 40, dy: frame.minY + 200))
    side.press(forDuration: 0.05, thenDragTo: side.withOffset(CGVector(dx: -260, dy: 0)), withVelocity: 500, thenHoldForDuration: 0.1)
    settle()
    XCTAssertEqual(page(), 2)
    let back = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.minX + 40, dy: frame.minY + 200))
    back.press(forDuration: 0.05, thenDragTo: back.withOffset(CGVector(dx: 260, dy: 0)), withVelocity: 500, thenHoldForDuration: 0.1)
    settle()
    XCTAssertEqual(page(), 1)
    // The drag moves the content from where the pan is recognised, and XCUITest loses a little
    // of every drag: 16 pt to make up.
    drag(card: 1, by: CGFloat(state("scroll")) + 16)
    settle()
    XCTAssertEqual(top(of: 1), medium, accuracy: 1, "the card is still at .medium")
    XCTAssertLessThanOrEqual(state("scroll"), 1, "the content is back at its top")
    snapshot("medium-title-back")
    XCTAssertGreaterThan(titleHeight(), 30, "with its large title again")
  }

  /// The user's report: at `.medium`, a card scrolled in place, then the next one touched — that
  /// first touch scrolled the next card to where the first had been left.
  func testTouchingTheNextCardKeepsItsOwnScroll() {
    app.terminate()
    app.launchArguments = Self.arguments(["-detents", "medium"])
    app.launch()
    app.buttons["row.1"].tap()
    XCTAssertTrue(app.scrollViews["card.1"].waitForExistence(timeout: 5))
    settle()
    drag(card: 1, by: -200)
    settle()
    XCTAssertGreaterThan(state("scroll"), 100, "the first card's content scrolled")
    let frame = app.scrollViews["card.1"].frame
    let side = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.maxX - 40, dy: frame.minY + 200))
    side.press(forDuration: 0.05, thenDragTo: side.withOffset(CGVector(dx: -260, dy: 0)), withVelocity: 500, thenHoldForDuration: 0.1)
    settle()
    XCTAssertEqual(page(), 2)
    XCTAssertGreaterThan(titleHeight(), 30, "the next card shows its large title")

    app.scrollViews["card.2"].tap()
    settle()
    snapshot("next-card-touched")
    XCTAssertLessThanOrEqual(state("scroll"), 1, "the touch did not scroll the next card")
    XCTAssertGreaterThan(titleHeight(), 30, "which keeps its large title")
  }

  /// The same in full screen: scrolled and back, the large title returns without leaving it.
  func testLargeTitleReturnsFullScreen() {
    app.buttons["row.2"].tap()
    XCTAssertTrue(app.scrollViews["card.2"].waitForExistence(timeout: 5))
    settle()
    drag(card: 2, by: -300)
    settle()
    XCTAssertEqual(top(of: 2), 0, accuracy: 1)
    XCTAssertLessThan(titleHeight(), 30, "scrolled, the title is in the bar")
    drag(card: 2, by: CGFloat(state("scroll")) + 16)
    settle()
    XCTAssertEqual(top(of: 2), 0, accuracy: 2, "still full screen")
    XCTAssertLessThanOrEqual(state("scroll"), 1, "the content is back at its top")
    snapshot("fullscreen-title-back")
    XCTAssertGreaterThan(titleHeight(), 30, "with its large title again")
  }

  /// A pan is recognised only after the finger has moved some way — further the faster it
  /// starts — and its translation already holds that distance. The card must not leap to catch
  /// up in the drag's first frame: a quick 40 pt drag rose the card 30 pt with the leap and 19
  /// without (XCUITest loses some of every drag).
  func testDragStartsWithoutLeap() throws {
    // Between `.large` and full screen the card stays where it is let go, so the drag can be
    // read after it.
    app.buttons["row.2"].tap()
    XCTAssertTrue(app.scrollViews["card.2"].waitForExistence(timeout: 5))
    settle()
    try requireRoomAboveLarge()
    let large = top(of: 2)
    let frame = app.scrollViews["card.2"].frame
    let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX - 60, dy: frame.minY + 300))
    start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -40)), withVelocity: 600, thenHoldForDuration: 0.5)
    settle()
    let rise = large - top(of: 2)
    XCTAssertGreaterThan(rise, 10, "the card follows the drag")
    XCTAssertLessThan(rise, 25, "but not the distance moved before it was recognised (\(rise))")
  }

  /// The user's report: after switching between `.medium` and `.large`, the first touch moved
  /// the large title sideways inside its card (3 pt) — its margin was re-applied from a minimum
  /// UIKit measures against the display's edge, so it depended on where the card was.
  func testFirstTouchAfterSwitchingDetentsKeepsTitle() {
    app.terminate()
    app.launchArguments = Self.arguments(["-detents", "mediumAndLarge"])
    app.launch()
    app.buttons["row.2"].tap()
    XCTAssertTrue(app.scrollViews["card.2"].waitForExistence(timeout: 5))
    settle()
    let margin = largeTitleMargin(card: 2)
    for (move, tapY) in [(-250.0, 400.0), (250.0, 650.0)] {
      drag(card: 2, by: move)
      settle()
      let before = largeTitleMargin(card: 2)
      XCTAssertEqual(before, margin, accuracy: 0.5, "the title keeps its margin through the move")
      app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 200, dy: tapY)).tap()
      settle()
      XCTAssertEqual(largeTitleMargin(card: 2), before, accuracy: 0.5, "and a touch does not move it")
    }
  }

  /// From `.large` to full screen the large title holds still on screen while the card's top
  /// edge rises past it: at `.large` the bar sits on UIKit's padding under the grabber, and the
  /// safe area above it grows by exactly as much as the card rises — the title never moves.
  func testLargeTitleFollowsTheSafeArea() throws {
    app.buttons["row.2"].tap()
    XCTAssertTrue(app.scrollViews["card.2"].waitForExistence(timeout: 5))
    settle()
    let title = app.navigationBars.staticTexts["Card 3"].firstMatch
    let atLarge = title.frame.minY
    // UIKit's padding is 10 pt under a status bar, 16 pt on an iPhone Duo.
    XCTAssertEqual(atLarge - top(of: 2), 10 + 44 + 8, accuracy: 10, "at .large the bar sits on UIKit's padding, not under a status bar's height")
    try requireRoomAboveLarge()
    let frame = app.scrollViews["card.2"].frame
    let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX - 60, dy: frame.minY + 300))
    start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -40)), withVelocity: 300, thenHoldForDuration: 0.4)
    settle()
    let middle = top(of: 2)
    XCTAssertGreaterThan(middle, 5, "the card stopped between .large and full screen (\(middle))")
    XCTAssertLessThan(middle, restingTop - 12)
    XCTAssertEqual(title.frame.minY, atLarge, accuracy: 1, "the title held still")
    drag(card: 2, by: -60)
    settle()
    XCTAssertEqual(top(of: 2), 0, accuracy: 1, "full screen")
    // The drag may carry a few points into the content, which moves the title with it.
    XCTAssertEqual(title.frame.minY + CGFloat(state("scroll")), atLarge, accuracy: 1, "and holds at full screen")
  }

  /// From the card's leading edge to its large title.
  private func largeTitleMargin(card index: Int) -> CGFloat {
    let title = app.navigationBars.staticTexts["Card \(index + 1)"].firstMatch
    return title.frame.minX - app.scrollViews["card.\(index)"].frame.minX
  }

    /// The user's flow: open, then a slow sideways drag right away, held, released.
  func testSlowSidewaysDragKeepsTitleMargin() {
    app.terminate()
    app.launchArguments = Self.arguments(["-detents", "mediumAndLarge"])
    app.launch()
    app.buttons["row.2"].tap()
    XCTAssertTrue(app.scrollViews["card.2"].waitForExistence(timeout: 5))
    let frame = app.scrollViews["card.2"].frame
    let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.minY + 200))
    start.press(forDuration: 0.3, thenDragTo: start.withOffset(CGVector(dx: -120, dy: 0)), withVelocity: 80, thenHoldForDuration: 0.5)
    settle()
    start.press(forDuration: 0.3, thenDragTo: start.withOffset(CGVector(dx: 120, dy: 0)), withVelocity: 80, thenHoldForDuration: 0.5)
    settle()
  }

    /// Detents that stop short of `.large` never go full screen: a long drag up leaves the card at
  /// its largest detent and scrolls the content instead.
  func testNoFullScreenWithoutLarge() {
    app.terminate()
    app.launchArguments = Self.arguments(["-detents", "medium"])
    app.launch()
    app.buttons["row.1"].tap()
    XCTAssertTrue(app.scrollViews["card.1"].waitForExistence(timeout: 5))
    settle()
    let medium = top(of: 1)
    XCTAssertGreaterThan(medium, app.windows.firstMatch.frame.height / 3, "the card rests at .medium")

    drag(card: 1, by: -300)
    settle()
    snapshot("medium-only-dragged")
    XCTAssertEqual(top(of: 1), medium, accuracy: 1, "it stays at .medium, its largest detent")
    XCTAssertGreaterThan(state("scroll"), 100, "and the drag scrolled the content")
    XCTAssertEqual(state("grabber"), 1, "the grabber stays: the card is not full screen")
  }

  // MARK: Helpers

  private func bottom() -> CGFloat {
    let value = app.otherElements["cardSheet.state"].value as? String ?? ""
    let bottom = value.split(separator: " ").first { $0.hasPrefix("bottom=") }?.dropFirst(7)
    return bottom.flatMap { Double($0) }.map { CGFloat($0) } ?? -1
  }

  private func grabber() -> Double {
    let value = app.otherElements["cardSheet.state"].value as? String ?? ""
    let grabber = value.split(separator: " ").first { $0.hasPrefix("grabber=") }?.dropFirst(8)
    return grabber.flatMap { Double($0) } ?? -1
  }

  /// The tallest visible navigation title: ~41 pt large, ~20 pt inline. (The bar's own frame
  /// leaves the large title out.)
  private func titleHeight() -> CGFloat {
    app.navigationBars.staticTexts.allElementsBoundByIndex
      .filter { $0.isHittable }
      .map(\.frame.height)
      .max() ?? 0
  }

  /// A number the sheet reports in its test state: `top`, `page`, `bottom`, `grabber`, `scroll`,
  /// `large`.
  private func state(_ key: String) -> Int {
    let value = app.otherElements["cardSheet.state"].value as? String ?? ""
    let field = value.split(separator: " ").first { $0.hasPrefix(key + "=") }?.dropFirst(key.count + 1)
    return field.flatMap { Int($0) } ?? -1
  }

  /// A short, fast drag released while still moving: the content carries on by momentum.
  private func flick(card index: Int, by dy: CGFloat) {
    let frame = app.scrollViews["card.\(index)"].frame
    let start = app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: frame.midX, dy: 300))
    start.press(forDuration: 0.02, thenDragTo: start.withOffset(CGVector(dx: 0, dy: dy)),
          withVelocity: 2000, thenHoldForDuration: 0)
  }

  private func page() -> Int {
    let value = app.otherElements["cardSheet.state"].value as? String ?? ""
    let page = value.split(separator: " ").first { $0.hasPrefix("page=") }?.dropFirst(5)
    return page.flatMap { Int($0) } ?? -1
  }


  /// A drag from inside the card, held still at the end so it is released without velocity.
  private func drag(card index: Int, by dy: CGFloat) {
    let frame = app.scrollViews["card.\(index)"].frame
    let screen = app.windows.firstMatch.frame
    let startY = dy < 0 ? min(frame.maxY, screen.maxY) - 60 : max(frame.minY, 0) + 110
    let start = app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: frame.midX, dy: startY))
    let end = start.withOffset(CGVector(dx: 0, dy: dy))
    start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 600, thenHoldForDuration: 0.4)
  }

  /// The current card's top, as the sheet reports it (`index` names the card the test expects
  /// to be current; SwiftUI's offset leaves accessibility frames where layout put them).
  private func top(of index: Int) -> CGFloat {
    let value = app.otherElements["cardSheet.state"].value as? String ?? ""
    let top = value.split(separator: " ").first { $0.hasPrefix("top=") }?.dropFirst(4)
    return top.flatMap { Double($0) }.map { CGFloat($0) } ?? -1
  }

  private func settle() {
    Thread.sleep(forTimeInterval: 1.0)
  }

  private func snapshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
