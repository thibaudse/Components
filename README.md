# Components

Reusable Swift components, each one a standalone SwiftPM library with no third-party
dependencies.

## Components

| Component | What it is | Platforms |
| --- | --- | --- |
| **CalendarKit** | A SwiftUI month grid, plus a single-row inline calendar. It places the days; you draw them, and the chrome around them. | iOS 18+, macOS 14+ |
| **NavigationSheetKit** | A sheet that navigates within itself, resizes to whatever screen is showing, and keeps every screen's state while it is out of view. | iOS 18+ |

## Installation

In Xcode: **File ▸ Add Package Dependencies…**, then enter

```
https://github.com/thibaudse/Components
```

and pick the libraries you need. In a `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/thibaudse/Components", from: "1.0.0")
],
targets: [
  .target(
    name: "MyFeature",
    dependencies: [
      .product(name: "CalendarKit", package: "Components")
    ]
  )
]
```

Products are independent: depending on `CalendarKit` builds `CalendarKit` and nothing
else. SwiftPM resolves a package from the manifest at a repository's root, so all
components share one root `Package.swift` rather than living in nested package
directories — one repository, one dependency entry, one library per component.

## CalendarKit

The calendar is the grid; the chrome is yours, added as toolbars that receive the
calendar's state and actions.

```swift
import CalendarKit
import SwiftUI

struct MonthPicker: View {
  @State private var currentDay = Calendar.autoupdatingCurrent.today
  @State private var selection: DateComponents?

  var body: some View {
    CalendarView(currentDay: $currentDay)
      .calendarToolbar { month in
        HStack {
          Text(month.monthName).font(.headline)
          Text(month.yearTitle).foregroundStyle(.secondary)

          Spacer()

          Button("Previous", systemImage: "chevron.left", action: month.goToPreviousMonth)
          Button("Next", systemImage: "chevron.right", action: month.goToNextMonth)
        }
        .labelStyle(.iconOnly)
      }
      .calendarCell { day in
        Button {
          selection = day
        } label: {
          Text(day.day?.formatted(.number) ?? "")
            .foregroundStyle(day == selection ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
      }
  }
}
```

- **`CalendarView`** — the month grid and the weekday row, nothing else. Months slide in
  the direction of travel whatever moves the binding. Days come back to you as
  `DateComponents`; column headings as `CalendarWeekday`.
- **`CalendarProxy`** — what every toolbar closure receives: the visible month
  (`monthTitle`, `monthName`, `yearTitle`, `year`, `month`, `daysInMonth`,
  `firstDayOfMonth`, `lastDayOfMonth`, `containsToday`, `animation`) and the actions that
  move it (`goToNextMonth()`, `goToPreviousYear()`, `goToToday()`, `go(to:)`, …).
- **`CalendarMonthHeader`** — the conventional title-plus-chevrons header, for when you
  don't want to build one: `.calendarToolbar { CalendarMonthHeader($0) }`.
- **`InlineCalendarView`** — one row of days for widgets and list rows, drawing exactly
  the dates you hand it.
- **The calendar comes from the environment** — `\.calendar` decides the first weekday,
  the weekday symbols, the title's language, and the month lengths:
  `.environment(\.calendar, mondayFirst)`. There is no calendar parameter to pass, and the
  bound day is re-derived through it so nothing can disagree.
- **Styling by inheritance** — there is no theme. The calendar draws unstyled text, so
  `.font()`, `.foregroundStyle()`, and `.tint()` applied to it reach the days, the weekday
  symbols, and your toolbars alike. `.calendarSpacing(rows:columns:weekdays:toolbars:)`
  sets the gaps; `.calendarAnimation(_:)` and `.calendarTransition(_:)` set the motion —
  scoped to the grid, so a month change never animates your state along with it; and
  `.calendarDrawingGroup(false)` opts out of flattening the grid when a cell needs a
  material or a shadow that must not be rasterized.
- **Date helpers** — `DateComponents` month and year navigation, month layout, weekday
  tests, and chronological comparison.

Full API reference and guides live in the DocC catalog — see below.

### Styling

```swift
CalendarView(currentDay: $currentDay)
  .calendarWeekdaySymbol { weekday in
    Text(weekday.symbol.prefix(1).localizedUppercase)
      .font(.caption2.weight(.bold))
      .foregroundStyle(weekday.isWeekend ? .tertiary : .secondary)
  }
  .calendarCell { day in
    Text(day.day?.formatted(.number) ?? "")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background { if day.isWeekend { Circle().fill(.quaternary) } }
  }
  .calendarSpacing(rows: 12, weekdays: 8)
  .font(.system(size: 17, weight: .medium, design: .rounded))
```

Every part is either inherited from the environment or replaceable outright: days, column
headings (or the whole row), chrome above and below, the gaps between them, and the
month-change animation and transition. Nothing is hidden behind a style type.

### Localization

Month names, weekday symbols, and day numbers are formatted from the calendar's locale.
The only literal strings are the two accessibility labels on `CalendarMonthHeader`'s
chevrons; they
are `LocalizedStringResource` values resolved from the component's own string catalog
(`Sources/CalendarKit/Resources/Localizable.xcstrings`), so they translate independently of
the host app. Add a language by adding it to that catalog under
`calendar.header.previousMonth` and `calendar.header.nextMonth`.

Xcode and `swift build --build-system swiftbuild` compile string catalogs; SwiftPM's legacy
native build system copies them uncompiled, where lookups fall back to their English
default values.

## NavigationSheetKit

A `NavigationStack` inside a `.sheet` almost works. What it does not do is resize the sheet
as you move between screens, and it loses each screen's state the moment you pop it. This is
the sheet that does both.

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

- **It sizes itself.** Each screen is measured — geometry for fixed content, scroll geometry
  for scrollable content, so a scroll view with a `safeAreaInset` bottom bar comes out right
  without being told about it — and the sheet takes that height, capped at large.
  `.navigationSheetDetent(.detent(.large))` when the measurement is not what you want.
- **It keeps state.** Every screen on the path stays in the hierarchy while it is behind the
  current one: pushed aside, blurred, and hidden from hit testing and accessibility, but never
  torn down. Come back to a pushed screen and its scroll position and `@State` are intact.
- **It has a bar, not a navigation bar.** `NavigationSheetToolbarItem` values are declared per
  screen with `.navigationSheetToolbar { }` and collected into one bar the sheet draws itself,
  which is what lets the bar crossfade its contents while the screens slide underneath.
- **`NavigationSheetPath` / `NavigationSheetLink`** — `NavigationPath` and
  `NavigationLink(value:)`, for a sheet. Destinations are registered per value type with
  `.navigationSheetDestination(for:)`; pushing an unregistered type reports a fault rather
  than showing a blank screen.
- **`\.navigationSheetDismiss`** — the in-sheet `\.dismiss`. Plain, it pops one screen or
  dismisses at the root; `dismiss(.all)` always dismisses.
- **Neutral defaults, all replaceable** — the sheet background, bar background, drag
  indicator, navigation button, and toolbar button style each have a modifier that replaces
  them. There is no theme type and no style enum, and nothing else is drawn for you.

### Styling

```swift
.navigationSheet(isPresented: $isPresented, path: $path) { RootScreen() }
  .navigationSheetBackground { Color.black.opacity(0.95) }
  .navigationSheetBarBackground {
    LinearGradient(colors: [.indigo.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
      .ignoresSafeArea()
  }
  .navigationSheetDragIndicator { Capsule().fill(.orange).frame(width: 40, height: 4) }
```

Out of the box: the system's sheet background; `safeAreaBar`'s own treatment on iOS 26+ and a
downward-fading `.ultraThinMaterial` below it; a `.tertiary` capsule; a close button at the
root and a back button once pushed, with localized accessibility labels; and toolbar buttons
at `.bordered`, becoming `.glass` at the large detent on iOS 26+.

The background you supply is drawn in the sheet's own environment, so it can read
`\.navigationSheetIsLargeDetent` and change with the sheet's height. Per-screen chrome —
navigation button, toolbar button style, background overlay — is declared on the screen,
alongside its toolbar items.

What is *not* replaceable: the bar height, indicator height, blur radius, and animation
duration. The bar's height feeds the detent arithmetic, so a caller changing it would change
how tall every screen believes it is. Need a materially different bar? Hide it with
`.navigationSheetToolbar(.hidden)` and put your own at the top of the screen.

### Localization

The only strings the component displays are the two accessibility labels on the built-in
navigation button, resolved from `Sources/NavigationSheetKit/Resources/Localizable.xcstrings`
via `Bundle.module`. Add a language by adding it to that catalog under
`navigationSheet.button.back` and `navigationSheet.button.close`.

The Swift property names (`navigationBack`, `navigationClose`) deliberately differ from those
keys: Xcode generates its own accessors from a string catalog, named after the key, and a
hand-written property matching one compiles under `swift build` and then collides in Xcode.

### iOS only

`PresentationDetent` does not exist on macOS and detents are most of what this component does,
so the target is wrapped in `#if os(iOS)` and compiles to nothing elsewhere. A multiplatform
package can depend on it unconditionally; guard the call sites. `NavigationSheetPath` and the
detent arithmetic are outside the guard, which is how they stay testable under `swift test` on
macOS.

## Documentation

Each component carries a DocC catalog with a landing page, guides, and API reference.
In Xcode: **Product ▸ Build Documentation**. From the command line:

```sh
xcodebuild docbuild -scheme Components -destination 'generic/platform=iOS'
```

CalendarKit's catalog covers: **Getting started**, **Theming**, and **Working with
DateComponents**. NavigationSheetKit's covers: **Getting started**, **Toolbars**, **Sizing**,
and **Styling**.

## Repository layout

```
Package.swift                        one manifest, one library product per component
Sources/
  CalendarKit/
    Views/                           public views
    Model/                           proxy, weekday, placement, direction
    Extensions/                      public Calendar / DateComponents / Date helpers
    Internal/                        implementation details
    Resources/                       string catalog
    CalendarKit.docc/                landing page and guides
  NavigationSheetKit/
    NavigationSheet.swift            the public View modifiers
    NavigationSheet+Previews.swift   the sizing cases, one destination each
    Views/                           public views
    Model/                           path, dismiss, placements, detents
    Internal/                        container, preferences, measurement, chrome
    Resources/                       string catalog
    NavigationSheetKit.docc/         landing page and guides
Tests/
  CalendarKitTests/
  NavigationSheetKitTests/
```

## Adding a component

1. Create `Sources/<Name>Kit/` and add a `.target` plus a `.library` product to
   `Package.swift`.
2. Keep it self-contained: no dependency on another component and no third-party
   dependencies, so a consumer can adopt one component without inheriting the rest.
3. Take styling from the caller: draw unstyled content so SwiftUI's environment reaches it,
   and give every part it cannot infer a modifier that replaces it. No theme types, no
   style enums, no design system.
4. Localize any string the component displays: a `LocalizedStringResource` with an explicit
   key and default value, resolved from the component's own
   `Resources/Localizable.xcstrings` via `Bundle.module`. Prefer formatters over literals —
   dates, numbers, and measurements localize themselves.
5. Add a `<Name>Kit.docc` catalog with a landing page and at least a getting-started
   guide, and document every public symbol.
6. Add `Tests/<Name>KitTests/` for the logic that is testable without a view hierarchy.
7. Add a row to the components table above.

## Development

```sh
swift build
swift test
```

## License

MIT — see [LICENSE](LICENSE).
