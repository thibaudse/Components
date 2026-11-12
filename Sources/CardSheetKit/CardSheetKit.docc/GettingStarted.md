# Getting started

Present a card, or several to page through.

## Overview

The presenters are overloads of `sheet`. Inside, the content takes the `.presentation*` modifiers
it would on any sheet.

### Present several cards

One card per item, side by side, opened on `selection`. Swiping sideways moves between them at any
height but full screen, and `selection` follows the card on screen. Dismissing sets it to `nil`.

```swift
@State private var selectedGame: Game.ID?

var body: some View {
  List(games) { game in
    Button(game.title) { selectedGame = game.id }
  }
  .sheet(items: games, selection: $selectedGame) { game in
    GameView(game)
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
  }
}
```

### Present one card

Driven by a Boolean or by an item, as with `sheet`. These two take `style: .card`: SwiftUI's own
`sheet(isPresented:)` and `sheet(item:)` have exactly their other parameters, so without it every
call would be ambiguous, and every sheet in the app would become a card.

```swift
.sheet(isPresented: $isShowingScore, style: .card) {
  ScoreView()
}

.sheet(item: $selectedPlayer, style: .card) { player in
  PlayerView(player)
}
```

### Configure it with SwiftUI's modifiers

The content's presentation modifiers are read back from the sheet SwiftUI configures:

| Modifier | On the card |
| --- | --- |
| `presentationDetents` | The card rests at the smallest detent and can be dragged between them. It goes on to full screen only if they reach `.large`. Below `.large` it floats, 8 pt from the sides and bottom; it reaches the edges at `.large`. The content is laid out in the space the card offers. |
| `presentationDetents(_:selection:)` | Moves the card when the selection changes. A dragged-to detent is not written back. |
| `presentationDragIndicator` | The card's grabber, at every height but full screen. |
| `presentationCornerRadius` | The resting corner radius. |
| `presentationBackgroundInteraction(.enabled(upThrough:))` | No dimming at or below that detent. |
| `presentationContentInteraction(.scrolls)` | The content scrolls natively at every height, instead of the card rising first. |
| `interactiveDismissDisabled` | No pull-down or background-tap dismissal. |

### Options a system sheet has no equivalent for

```swift
GameView(game)
  .presentationSnapping(.always)          // spring to the nearest detent on release
  .presentationExpandsToFullScreen(false) // stop at .large
  .presentationNeighbourPeek(16)          // show more of the neighbouring cards
```

- ``SwiftUICore/View/presentationSnapping(_:)`` — whether a card released between two resting
  places springs to one. `.automatic`, the default, snaps when there are several detents.
- ``SwiftUICore/View/presentationExpandsToFullScreen(_:)`` — whether a card that reaches `.large`
  goes on over the status bar.
- ``SwiftUICore/View/presentationNeighbourPeek(_:)`` — how much of each neighbour shows.

Content that wants to react to the card's height reads
``SwiftUICore/EnvironmentValues/presentationExpansion``: 0 at the resting detent, 1 at full
screen.

### Navigation stacks

Content in a `NavigationStack` behaves as on a full-screen screen. The bar's spacing comes from the
safe area, so from `.large` to full screen the bar and its large title hold still on screen while
the card's edge passes them. At full screen the bar stays fixed, and its large title collapses as
the content scrolls and comes back at the top. A drag on the bar moves the content and the card, as
a drag on the content does.

### Not supported yet

`presentationBackground` (give the content its own background), writing a dragged-to detent back
into a selection binding, touches passing through to the presenter when background interaction is
enabled, and `presentationSizing` or compact adaptations on iPad.
