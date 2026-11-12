# ``CardSheetKit``

Cards you page through sideways, resting at a detent, that one drag takes to full screen and on
into the content — and back down, and away.

## Overview

CardSheetKit adds overloads of `sheet` that present their content as a card, the way Apple Sports
presents a game. The card rests at its smallest detent, floating below `.large` as iOS 26 sheets do.
A single drag takes it up through its detents to full screen and carries straight on into the
content's own scrolling, then back down and away, without the finger ever lifting.
`sheet(items:selection:)` lays several cards side by side, with the neighbours peeking in the
margins, to swipe between at any height but full screen.

```swift
List(games) { game in
  Button(game.title) { selectedGame = game.id }
}
.sheet(items: games, selection: $selectedGame) { game in
  GameView(game)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
}
```

It is still a SwiftUI sheet: the content takes SwiftUI's own presentation modifiers, read back
from the sheet SwiftUI configures, plus a few a system sheet has no equivalent for.

> Important: CardSheetKit is built on private UIKit API. Every call checks that its selector exists
> first, so a missing one is logged and skipped rather than crashing, but none of it would pass App
> Review. See <doc:HowItWorks>.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:HowItWorks>

### Presenting

- ``SwiftUICore/View/sheet(items:selection:onDismiss:content:)``
- ``SwiftUICore/View/sheet(isPresented:style:onDismiss:content:)``
- ``SwiftUICore/View/sheet(item:style:onDismiss:content:)``
- ``SheetStyle``

### Options a system sheet has no equivalent for

- ``SwiftUICore/View/presentationSnapping(_:)``
- ``PresentationSnapping``
- ``SwiftUICore/View/presentationExpandsToFullScreen(_:)``
- ``SwiftUICore/View/presentationNeighbourPeek(_:)``

### Reading the card's position

- ``SwiftUICore/EnvironmentValues/presentationExpansion``
