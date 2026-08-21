# Sizing

How the sheet decides how tall to be, and when to tell it yourself.

## Overview

Every screen is measured, and the sheet takes that screen's height. Move to another screen and
the sheet animates to its height instead. Nothing to configure — but it is worth knowing what
is being measured, because that is what determines whether the answer is right.

### What gets measured

A screen's requested height is `topInset + contentHeight + bottomInset`, and those three numbers
come from one of two places.

**Fixed content** answers from its geometry: whatever height it lays out at.

**Scrollable content** answers from scroll geometry — content size plus content insets — not
from its frame. A scroll view's frame is whatever the sheet currently is, so measuring it would
just report the answer back to itself. Content insets are how a `safeAreaInset` bottom bar gets
counted, which is why a scroll view with a bottom bar sizes correctly without being told about
it.

Whichever source speaks first, scroll geometry wins once it has produced a usable reading.

### The cap

A screen taller than the sheet can ever be gets the large detent rather than an unreachable
fixed height. This is why the package defines its own large detent: `.large` will not report the
height it resolved to, and the cap needs that number.

### Overriding

`navigationSheetDetent(_:)` replaces the measurement for one screen:

```swift
// Always full height, whatever the content
ScrollView { … }
  .navigationSheetDetent(.detent(.large))

// A fixed height
PickerScreen()
  .navigationSheetDetent(.detent(.height(320)))

// The default
DetailScreen()
  .navigationSheetDetent(.automatic)
```

Reach for it when measurement gives the wrong answer for a reason the sheet cannot see: content
that grows as data loads, where a growing sheet is more distracting than a tall one; or a screen
whose height depends on a keyboard.

### Why it animates the way it does

SwiftUI only interpolates between detents a sheet has been offered, so a change adds both the
old and the new detent, selects the new one a frame later, and drops the old one once the
animation finishes. That last step matters: leaving them all in place would let a drag snap to
any height the sheet had ever been.

One consequence to know about. A detent change alters a scroll view's content insets, which
changes the measurement, which would change the detent — a loop. The sheet breaks it by treating
a screen's bottom inset as a high-water mark: it can grow but never shrink while that screen is
showing. A screen whose bottom bar disappears will keep the space it reserved.

### Zero heights

A view reports a height of zero before its geometry resolves. Zero is treated as "has not
answered yet" rather than as a height, so the sheet stays where it is until a real number
arrives. This is also why a freshly pushed screen drops any measurement left over from a
previous visit — otherwise the sheet would jump to that screen's old height for a frame before
correcting.
