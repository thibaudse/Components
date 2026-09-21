# Styling

What the sheet draws, what it inherits, and how to replace each piece.

## Overview

There is no theme type and no style enum. The sheet draws four things of its own — a
presentation background, a bar background, a drag indicator, and a navigation button — and each
one is a modifier away from being something else. Everything else is your content, so fonts,
colors, and tint reach it through the environment like any other SwiftUI view.

### The defaults

| Piece | Default |
| --- | --- |
| Presentation background | The system's, untouched |
| Bar background | `safeAreaBar`'s own treatment on iOS 26+; a downward-fading `.ultraThinMaterial` below |
| Drag indicator | A 60×4 capsule filled with `.tertiary` |
| Navigation button | Close at the root, back once pushed, styled like a toolbar button |
| Toolbar buttons | `.bordered`, becoming `.glass` at the large detent on iOS 26+ |
| Title | `.headline` |

### Replacing the chrome

The three sheet-wide pieces are set on the presenting view, because they belong to the whole
presentation rather than to one screen:

```swift
.navigationSheet(isPresented: $isPresented, path: $path) {
  RootScreen()
}
.navigationSheetBackground {
  Color.black.opacity(0.95)
}
.navigationSheetBarBackground {
  LinearGradient(colors: [.indigo.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
    .ignoresSafeArea()
}
.navigationSheetDragIndicator {
  Capsule().fill(.orange).frame(width: 40, height: 4)
}
```

Pass `EmptyView()` to a slot to remove what is there.

The background also takes a style, for when a `Rectangle` filled with one is all it was going
to be:

```swift
.navigationSheetBackground(.thinMaterial)
```

**The background is the one piece either end may declare.** Set it inside a screen and it
applies to that screen alone, winning over the presenting view's — a screen that paints its own
panel is making the more specific statement, and it is the screen that knows it:

```swift
.navigationSheet(isPresented: $isPresented) {
  SessionPreview()
    .navigationSheetToolbar(.hidden)
    .navigationSheetBackground(.thinMaterial)
}
```

It reaches the sheet from either side because the modifier publishes on both channels: the
environment, which the presenter snapshots from its own position in the tree, and a preference,
which travels outward to the screen's host — the only direction that reaches the container from
inside the sheet. The bar background and the drag indicator stay presenting-view only; they are
part of one bar shared by every screen, and nothing has needed to vary them per screen.

The background you supply is drawn inside the sheet's own environment, so it can read
`\.navigationSheetIsLargeDetent` and change with the sheet's height:

```swift
.navigationSheetBackground {
  NavigationSheetBackground()
}

private struct NavigationSheetBackground: View {
  @Environment(\.navigationSheetIsLargeDetent) private var isLargeDetent

  var body: some View {
    (isLargeDetent ? Color.black : Color.clear).opacity(0.95)
  }
}
```

The change crossfades as the detent moves.

### Per-screen appearance

The navigation button, the toolbar button style, and background overlays are declared per screen,
alongside that screen's toolbar items:

```swift
DetailScreen()
  .navigationSheetNavigationButton {
    Button("Done") { dismiss() }
  }
  .navigationSheetBackgroundOverlay {
    LinearGradient(colors: [.purple.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
  }
```

A background overlay sits on top of the sheet's background and behind the screen's own content.
Moving between screens crossfades their overlays, which is what makes it the right place for a
gradient or image that belongs to one screen rather than to the sheet.

### What is not replaceable

The bar's height, the drag indicator's height, the push/pop transition, and the animation
duration are constants. They are not knobs because the bar's height feeds the detent arithmetic:
a caller changing it would change how tall every screen believes it is, and the failure would
show up as sheets that are subtly the wrong size rather than as anything obviously broken.

If you need a materially different bar, hide it — `navigationSheetToolbar(.hidden)` — and put
your own at the top of the screen's content.

### Inherited styling

Everything else is ordinary SwiftUI. The sheet draws no fonts or colors of its own beyond the
table above, so modifiers applied to the presenting view reach the sheet's content, and modifiers
applied inside a screen reach that screen:

```swift
.navigationSheet(isPresented: $isPresented, path: $path) {
  RootScreen()
}
.tint(.orange)                                        // reaches the sheet's buttons
.environment(\.dynamicTypeSize, .large)               // and its text
```
