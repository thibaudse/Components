# Components

Reusable Swift components, each one a standalone SwiftPM library with no third-party
dependencies.

## Components

| Component | What it is | Platforms |
| --- | --- | --- |
| **CalendarKit** | A SwiftUI month grid, plus a single-row inline calendar. It places the days; you draw them, and the chrome around them. | iOS 17+, macOS 14+ |

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
  `firstDayOfMonth`, `lastDayOfMonth`, `containsToday`) and the actions that move it
  (`goToNextMonth()`, `goToPreviousYear()`, `goToToday()`, `go(to:)`, …).
- **`CalendarMonthHeader`** — the conventional title-plus-chevrons header, for when you
  don't want to build one: `.calendarToolbar { CalendarMonthHeader($0) }`.
- **`InlineCalendarView`** — one row of days for widgets and list rows, drawing exactly
  the dates you hand it.
- **Styling by inheritance** — there is no theme. The calendar draws unstyled text, so
  `.font()`, `.foregroundStyle()`, and `.tint()` applied to it reach the days, the weekday
  symbols, and your toolbars alike. `.calendarSpacing(rows:columns:weekdays:toolbars:)`
  sets the gaps; `.calendarAnimation(_:)` and `.calendarTransition(_:)` set the motion.
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

## Documentation

Each component carries a DocC catalog with a landing page, guides, and API reference.
In Xcode: **Product ▸ Build Documentation**. From the command line:

```sh
xcodebuild docbuild -scheme Components -destination 'generic/platform=iOS'
```

CalendarKit's catalog covers: **Getting started**, **Theming**, and **Working with
DateComponents**.

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
Tests/
  CalendarKitTests/
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
