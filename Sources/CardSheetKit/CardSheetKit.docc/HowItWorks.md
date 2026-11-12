# How it works

What the card is made of, the private API it relies on, and what it took to make it hold still.

## Overview

### SwiftUI's own sheet presents it

A `UIHostingController` presented by UIKit gets none of `presentationDetents` and the rest: only
SwiftUI's `sheet` applies them. So every presenter is SwiftUI's `sheet`, whose content is the
card sheet. A view inside that content reads the modifiers back from the real
`UISheetPresentationController`. Detents are resolved with UIKit's own resolvers, through a
context that implements the private methods they call. The sheet is then given a runtime subclass
whose setters record SwiftUI's later changes instead of applying them, and it becomes an invisible
full-screen host: full screen, its chrome cleared, no safe area.

### SwiftUI draws the cards; an engine moves them

The engine owns one distance for every vertical drag. Below 0, the current card is pulled away to
dismiss. From 0 it rises through the detents to full screen. Past that, the content scrolls. The
engine drives the content's own scroll view rather than letting it scroll, so a drag never hands
over between two things: a SwiftUI `ScrollView` cannot be held from outside mid-drag. Released,
every motion is stepped per display frame from the finger's speed: a scroll view's deceleration,
an exact critically damped spring, a rubber band at the bottom. A UIKit animation started on
release stuttered (a frozen first frame, then a catch-up jump).

### Private API

| Private | Used for |
| --- | --- |
| `_setWantsFullScreen:` | a sheet the size of the display |
| `_setAllowsInteractiveDismissWhenFullScreen:` | off: dismissal is the card's own drag |
| `_setPreferredShadowOpacity:`, `_setLargeBackground:`, `dropShadowView` | invisible, unclipped sheet chrome |
| `_confinedDimmingView` | the presenter's dimming, faded as a card is pulled away |
| the detent resolution context's private methods (`_containerBounds`, …) | resolving SwiftUI's detents exactly as UIKit does |
| `UINavigationController._verticalBarEligibleEdges`, in a runtime subclass | a card's navigation bar staying a sheet's where a status bar runs down the side of the display (iPhone Duo) |
| a runtime subclass of the sheet, and of the sheet's hosting view | seeing SwiftUI's later writes without applying them; fixing margins inside a layout pass |

Every selector is checked before it is called, and a missing one is logged and skipped. An
Objective-C exception from a detent resolver is caught. None of this would pass App Review.

### Keeping the content still

Most of the work went into making nothing move that should not. Each of these was found by
measuring frames: the simulator's, and a device's screen recordings matched to per-frame logs.

- **The safe area is the engine's.** The system's safe area reached the content one layout pass
  after the card moved, so whatever was pinned to it trailed the card. It is cancelled at the host,
  and the engine gives each `NavigationStack` its top safe area itself, in the same step as the
  card's position: UIKit's 10 pt padding at rest, growing above `.large` by exactly as much as the
  card rises. The title so holds still on screen from `.large` to full screen.
- **The content follows where the card is laid out, not where it was asked to be.** SwiftUI places
  the card's content in its own layout pass, which on a device can come a frame after the engine
  moves the card. The content offset and the bar's safe area are computed from the laid-out frame,
  and applied again after each layout pass, so they always match the frame they are drawn in.
- **Drags apply at the start of a display frame**, as release motions do. Applied in the touch
  callback, a drag reached the screen in two halves, and the title dipped by the finger's movement.
- **A pan's first translation is not movement.** A pan begins only once the finger has moved,
  about 11 pt when it starts quickly, and the card leapt that far. The drag starts where it is
  recognised, as a scroll view's does.
- **Margins are the card's own.** Inherited layout margins, and UIKit's minimum margins, are
  measured against the display's edge, so a moving card's title slid inside it. Each navigation
  controller gets a fixed 16 pt, set inside the layout pass that creates it.
- **The neighbours' room lasts to `.large`** and is used up only between `.large` and full screen,
  the one stretch where the card has to reach the display's width.
- **A card's content top is kept per card**, frozen at the top so a collapsing large title moves
  nothing and scrolling back returns to where UIKit expands it again, even after paging away.
