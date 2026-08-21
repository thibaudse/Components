# Getting started

Present a sheet, register its destinations, push onto its path.

## Overview

Three pieces: the presenting modifier, a path, and one destination registration per type of
value the path can hold.

### Present

`navigationSheet(isPresented:path:root:)` replaces `.sheet`. The path is a separate binding
because you often want to read it — to know how deep the user is, or to reset it — and because
a sheet that never pushes anything can leave it out entirely.

```swift
@State private var isPresented = false
@State private var path = NavigationSheetPath()

var body: some View {
  Button("Open") { isPresented = true }
    .navigationSheet(isPresented: $isPresented, path: $path) {
      RootScreen()
    }
}
```

There is an item-driven variant, and it is the better choice whenever the sheet's content
depends on a value:

```swift
@State private var editing: Recipe?

// …
.navigationSheet(item: $editing) { recipe in
  RecipeEditor(recipe: recipe)
}
```

The item is non-nil when the root is first built, so there is nothing to unwrap inside and no
frame in which the sheet exists without its subject.

### Register destinations

The path holds values; something has to turn a value back into a screen. Register one builder
per value type, on the root content or at the presenting call site — either reaches the sheet.

```swift
enum SettingsRoute: Hashable {
  case account
  case notifications
  case about
}

RootScreen()
  .navigationSheetDestination(for: SettingsRoute.self) { route in
    switch route {
      case .account: AccountScreen()
      case .notifications: NotificationsScreen()
      case .about: AboutScreen()
    }
  }
```

A value whose type was never registered does not push a blank screen: the sheet reports a fault
to the `NavigationSheetKit` subsystem — visible in Console.app — and leaves the path alone.

### Push

``NavigationSheetLink`` is `NavigationLink(value:)` for a sheet:

```swift
NavigationSheetLink(SettingsRoute.account) {
  Label("Account", systemImage: "person")
}
```

Or move the path yourself, from anywhere that can reach the binding:

```swift
path.append(SettingsRoute.account)
path.removeLast()
path.removeAll()
```

Removing more than the path holds clamps rather than crashes. That is deliberate: a back button
and a dismiss can race, and a library should not bring the app down over it.

### Pop and dismiss

`\.navigationSheetDismiss` is the in-sheet `\.dismiss`. Called plainly it pops one screen, or
dismisses the sheet if there is nothing to pop:

```swift
struct DetailScreen: View {
  @Environment(\.navigationSheetDismiss) private var dismiss

  var body: some View {
    VStack {
      Button("Back") { dismiss() }
      Button("Close everything") { dismiss(.all) }
    }
  }
}
```

Dismissing the sheet empties its path, so reopening it starts at the root.

### State survives a round trip

Every screen on the path stays in the hierarchy while it is behind the current one — pushed
aside, blurred, and hidden from hit testing and accessibility, but never torn down. A pushed
screen keeps its scroll position and its `@State` when you come back to it, and nothing has to
be lifted out to make that happen.

The corollary is that a screen deep in the path is still alive: `.task` does not restart when
you return to it, and `.onAppear` fires once. Watch `\.navigationSheetPathDepth` if a screen
needs to know it is the one on top.
