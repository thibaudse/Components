# Toolbars

Declare a screen's bar contents on the screen itself.

## Overview

The sheet draws one bar and each screen says what goes in it. Items are declared with
`navigationSheetToolbar { }` and belong to the screen that declares them, so pushing a
destination replaces the bar's contents rather than adding to them.

```swift
DetailScreen()
  .navigationSheetTitle("Details")
  .navigationSheetToolbar {
    NavigationSheetToolbarItem(placement: .topBarTrailing) {
      Button("Save", action: save)
    }
  }
```

Three placements: `.topBarLeading`, `.title`, and `.topBarTrailing`. Leading items sit after the
navigation button; the title is centred on the bar rather than on the space the buttons leave
over, so a long title stays centred.

### Titles

`navigationSheetTitle(_:)` is shorthand for a `.title`-placed item at `.headline`. When the
title is not a line of text — a segmented control, a name with a subtitle under it — declare the
item yourself:

```swift
.navigationSheetToolbar {
  NavigationSheetToolbarItem(placement: .title) {
    VStack(spacing: 2) {
      Text(recipe.name).font(.headline)
      Text(recipe.author).font(.caption).foregroundStyle(.secondary)
    }
  }
}
```

### Animating a slot

The bar crossfades a slot when the identity of what is in it changes. Depth changes always
count, which is what animates the bar as you navigate. Within one screen, pass an `id`:

```swift
NavigationSheetToolbarItem(id: isPlaying ? "pause" : "play", placement: .topBarTrailing) {
  Button(isPlaying ? "Pause" : "Play", action: toggle)
}
```

Without an `id` an item keeps one identity for its lifetime, so its content changes in place.

### The navigation button

The bar's leading slot starts with a button of its own: a close button at the root, a back
button once something has been pushed, each with a localized accessibility label. Replace it per
screen:

```swift
.navigationSheetNavigationButton {
  Button("Done") { dismiss() }
}
```

or remove it, for a screen the user should not be able to leave by tapping past it:

```swift
.navigationSheetNavigationButton(.hidden)
```

The override belongs to the screen that declares it, like any other bar content. A screen that
appears at more than one depth can read `\.navigationSheetPathDepth` and decide.

### Button styling

Toolbar buttons are styled for you, the way SwiftUI styles the buttons you put in its own
toolbar: `.bordered`, becoming `.glass` at the large detent on iOS 26 and later. A short sheet
is a card, where glass over content reads as a mistake; a sheet at full height is a screen, where
it does not.

Opt out per screen and style them yourself:

```swift
.navigationSheetToolbarButtonStyle(.hidden)
.navigationSheetToolbar {
  NavigationSheetToolbarItem(placement: .topBarTrailing) {
    Button("Save", action: save)
      .buttonStyle(.borderedProminent)
  }
}
```

### Hiding the bar

`navigationSheetToolbar(.hidden)` collapses the bar to just its drag indicator for one screen,
and the screen gets the height back. The sheet still measures and sizes exactly as before.

```swift
OnboardingScreen()
  .navigationSheetToolbar(.hidden)
```
