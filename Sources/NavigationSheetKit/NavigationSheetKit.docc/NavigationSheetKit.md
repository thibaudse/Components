# ``NavigationSheetKit``

A sheet that navigates within itself, sizes itself to whatever screen is showing, and keeps
every screen's state while it is out of view.

## Overview

A `NavigationStack` inside a `.sheet` almost works. What it does not do is resize the sheet as
you move between screens, and it loses each screen's state the moment you pop it. This package
is the sheet that does both.

```swift
import NavigationSheetKit
import SwiftUI

struct SettingsButton: View {
  @State private var isPresented = false
  @State private var path = NavigationSheetPath()

  var body: some View {
    Button("Settings") { isPresented = true }
      .navigationSheet(isPresented: $isPresented, path: $path) {
        SettingsRoot()
          .navigationSheetTitle("Settings")
          .navigationSheetDestination(for: SettingsRoute.self) { route in
            SettingsDetail(route: route)
          }
      }
  }
}
```

There is no theme, no style type, and no dependency on anything outside SwiftUI. The layout is
fixed — a bar height the detent arithmetic depends on — and everything you can see is either
inherited from the environment or replaceable by a modifier.

### The three things it does that a stack in a sheet does not

**It sizes itself.** Each screen is measured and the sheet takes that height, capped at large.
Fixed content and scroll views are both handled, including scroll views with a bottom bar.
Nothing to configure, and `navigationSheetDetent(_:)` when the measurement is not what you
want.

**It keeps state.** Every screen on the path stays in the view hierarchy. Push a detail screen,
come back, and the list is still scrolled where you left it, the text field still has its draft.
Only screens actually popped are removed.

**It has a bar, not a navigation bar.** Toolbar items are declared per screen and collected
into a bar the sheet draws itself, which is why the bar can crossfade its contents while the
screens slide underneath.

### Built on UIKit, skinned in SwiftUI

The sheet's spine is `UISheetPresentationController` and a container view controller; every
visible surface — screens, bar, chrome — is SwiftUI. That split is deliberate: UIKit owns
*when* things happen, which is what makes three behaviors possible that a SwiftUI sheet cannot
express. The sheet is laid out and measured before the presentation animation starts, so it
opens at the right height instead of opening large and correcting. A push and its resize run
inside one animation. And an edge swipe from the left pops interactively, the way a
navigation stack does.

### iOS only

`PresentationDetent` does not exist on macOS, and detents are most of what this package does.
The target compiles to nothing on other platforms, so a multiplatform package can depend on it
unconditionally — just guard the call sites.

## Topics

### Essentials

- <doc:GettingStarted>
- ``NavigationSheetPath``
- ``NavigationSheetLink``

### The bar

- <doc:Toolbars>
- ``NavigationSheetToolbarItem``
- ``NavigationSheetToolbarPlacement``
- ``NavigationSheetToolbarVisibility``
- ``NavigationSheetToolbarButtonStyle``

### Dismissing

- ``NavigationSheetDismissAction``
- ``NavigationSheetDismissBehavior``

### Detents

- <doc:Sizing>
- ``NavigationSheetPreferredDetent``

### Appearance

- <doc:Styling>
