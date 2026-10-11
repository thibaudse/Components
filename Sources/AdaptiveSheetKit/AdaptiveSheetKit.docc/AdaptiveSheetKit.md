# ``AdaptiveSheetKit``

A sheet that is as tall as its content, and resizes with it.

## Overview

`adaptiveSheet` is `sheet` with the detent taken care of. Both overloads take `sheet`'s exact
signatures, so a call site changes by one word:

```swift
import AdaptiveSheetKit
import SwiftUI

struct TipButton: View {
  @State private var isShowingTip = false

  var body: some View {
    Button("Show tip") { isShowingTip = true }
      .adaptiveSheet(isPresented: $isShowingTip) {
        TipView(onGotIt: { isShowingTip = false })
          .presentationDragIndicator(.visible)
      }
  }
}
```

Everything else about the presentation stays SwiftUI's. The grabber, the background, the corner
radius and dismissal are set with the usual `.presentation*` modifiers and
`interactiveDismissDisabled()` inside the content, and they keep working.

### What it sizes to

**Static content** is measured as laid out.

**A `ScrollView`** is measured by its content size and content insets, so the sheet hugs what it
scrolls rather than the frame the sheet gave it.

**A `NavigationStack`** is followed screen by screen. After a push or a pop, the sheet resizes to
the screen now on top, once the transition has finished. A screen that scrolls is followed through
its content size; one that does not is re-read while it is on top, so prefer a `ScrollView` for a
screen that can grow.

The sheet resizes, animated, whenever the content does — a row added, the keyboard coming and going.

### What it does not do

**Content taller than the screen stops at the large detent**, and scrolling past it is the
content's. Wrap static content in a `ScrollView` when Dynamic Type can grow it past the screen.

**Do not add `presentationDetents(_:)` inside.** The detent is this modifier's, and it replaces any
set there. A sheet that should not hug its content — a full-height list, a share sheet — stays on
`sheet`.

### How it sizes

SwiftUI only interpolates between detents a sheet has already been offered, so a `.height` detent
that followed the content would jump instead of resizing. The modifier sizes the sheet's own
`UISheetPresentationController` instead: it installs one custom detent and changes its value as
measurements arrive. Only the detents are touched, which is what keeps every `.presentation*`
modifier working.

The home indicator is paid once: a custom detent already leaves out the bottom safe area, so a
scroll view's copy of that inset is subtracted from its reading rather than counted twice.

### iOS only

`UISheetPresentationController` does not exist on macOS, so the target compiles to nothing there.
A multiplatform package can depend on it unconditionally; guard the call sites. The detent
arithmetic is outside the guard, which is how it stays testable under `swift test` on macOS.

## Topics

### Essentials

- <doc:GettingStarted>
