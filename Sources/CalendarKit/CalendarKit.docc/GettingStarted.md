# Getting started

Add the package, show a month, and make its days selectable.

## Install

In Xcode, choose **File ▸ Add Package Dependencies…** and enter:

```
https://github.com/thibaudse/Components
```

Then add the `CalendarKit` library to your target. In a `Package.swift`:

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

## Show a month

``CalendarView`` needs one binding: the day it should show. The month containing that day
is what gets drawn, and the header's chevrons move the binding a month at a time.

```swift
import CalendarKit
import SwiftUI

struct MonthView: View {
  @State private var currentDay = Calendar.autoupdatingCurrent.today

  var body: some View {
    CalendarView(currentDay: $currentDay)
  }
}
```

That already gives you a working, navigable month with default day numbers.

## Style the days

Real calendars need selection, badges, or availability. Pass a cell style and you own the
day entirely — ``CalendarView`` only guarantees it a square with an equal share of the
grid width.

```swift
struct MonthPicker: View {
  @State private var currentDay = Calendar.autoupdatingCurrent.today
  @State private var selection: DateComponents?

  var body: some View {
    CalendarView(currentDay: $currentDay)
      .withCellStyle { day in
        let isSelected = day == selection

        Button {
          selection = day
        } label: {
          Text(day.day?.formatted(.number) ?? "")
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
              if isSelected {
                Circle().fill(.tint)
              }
            }
        }
        .buttonStyle(.plain)
      }
  }
}
```

Comparing days with `==` compares `DateComponents` field by field. Because both values
here come from the same calendar via the same helpers, that works — see
<doc:WorkingWithDateComponents> for the details and for chronological ordering.

## Bound the range

Clamp navigation by disabling a chevron when the visible month reaches your limit.

```swift
let calendar = Calendar.autoupdatingCurrent

CalendarView(currentDay: $currentDay)
  .backwardDisabled(currentDay.firstDayOfMonth <= calendar.today.firstDayOfMonth)
  .forwardDisabled(currentDay.month == 12)
```

## Show a single row of days

For a widget or a list row, ``InlineCalendarView`` draws just the days you give it, with
their weekday symbols above.

```swift
InlineCalendarView(visibleDays: Date.now.days(pastDays: 3, futureDays: 3))
  .withCellStyle { date in
    Text(Calendar.current.component(.day, from: date).formatted(.number))
      .font(.system(size: 11, weight: .medium))
  }
  .frame(width: 156)
```

Days here have no default appearance — an inline calendar without a cell style is a row
of weekday symbols over empty squares.

## Accessibility and localization

Everything a calendar displays comes from the calendar and its locale: month names,
weekday symbols, and day numbers are all formatted, never hardcoded. Set the calendar's
`locale` — or rely on `Calendar.autoupdatingCurrent` — and the chrome follows.

The package contains exactly two literal strings: the accessibility labels on the
navigation chevrons. They are `LocalizedStringResource` values resolved from CalendarKit's
own string catalog, so they translate independently of your app's localizations. English
ships in the box; adding a language means adding it to
`Sources/CalendarKit/Resources/Localizable.xcstrings` under the keys
`calendar.header.previousMonth` and `calendar.header.nextMonth`.

Day cells are yours, and so is their accessibility. A cell built with
``CalendarView/withCellStyle(_:)`` reads out as whatever it contains — a bare `Text("17")`
announces "17". Give it the full date and its state:

```swift
CalendarView(currentDay: $currentDay)
  .withCellStyle { day in
    let date = day.date ?? .now

    Text(day.day?.formatted(.number) ?? "")
      .accessibilityLabel(Text(date.formatted(date: .complete, time: .omitted)))
      .accessibilityAddTraits(day == selection ? [.isButton, .isSelected] : .isButton)
  }
```

`Date.formatted(date:time:)` is locale-aware, so that label needs no strings of your own.

## Next steps

- <doc:Theming> — colors, fonts, and spacing for the calendar chrome.
- <doc:WorkingWithDateComponents> — the date helpers the views are built on.
