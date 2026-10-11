# Getting started

Present a sheet that fits its content.

## Overview

Replace `sheet` with `adaptiveSheet`. Nothing else changes.

### Present

Driven by a Boolean:

```swift
@State private var isShowingTip = false

var body: some View {
  Button("Show tip") { isShowingTip = true }
    .adaptiveSheet(isPresented: $isShowingTip) {
      TipView()
    }
}
```

Or by an item, when the content depends on a value. The content is only built with a non-nil
item, and a new item's identity replaces the sheet rather than updating it:

```swift
@State private var selectedOption: Option?

// …
.adaptiveSheet(item: $selectedOption) { option in
  OptionDetail(option: option)
}
```

Swiping the sheet away sets the binding back to `false` or `nil`, and `onDismiss` runs once the
sheet has gone — as with `sheet`.

### Style it as any sheet

The `.presentation*` modifiers go inside the content, exactly where they would on a plain sheet:

```swift
.adaptiveSheet(isPresented: $isPresented) {
  ConfirmationView()
    .presentationDragIndicator(.visible)
    .presentationBackground(.thinMaterial)
    .interactiveDismissDisabled()
}
```

Leave out `presentationDetents(_:)`: the height is the modifier's, and any detents set there are
replaced.

### Content that scrolls

A `ScrollView` is measured by what it scrolls, so a short list gets a short sheet:

```swift
.adaptiveSheet(isPresented: $isPresented) {
  ScrollView {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(options) { option in
        OptionRow(option: option)
      }
    }
    .padding()
  }
  .scrollBounceBehavior(.basedOnSize)
}
```

Content taller than the screen stops at the large detent and scrolls the rest. Static content that
could outgrow the screen — long text at a large Dynamic Type size — should be wrapped in a
`ScrollView` for the same reason.

### Navigation inside the sheet

Put a `NavigationStack` inside, and the sheet resizes to each screen as it is pushed or popped:

```swift
.adaptiveSheet(isPresented: $isPresented) {
  NavigationStack(path: $path) {
    RootScreen()
      .navigationDestination(for: Route.self) { route in
        DetailScreen(route: route)
      }
  }
}
```

The resize lands once the push or pop has finished, not alongside it. A screen that scrolls is
followed through its content size at no cost; one that does not is re-read every frame while it is
on top, so prefer a `ScrollView` for a screen whose height changes.
