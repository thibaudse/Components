# Getting started

Add the package, show a month, then build the chrome around it.

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
is what gets drawn.

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

That is a grid of day numbers under a row of weekday symbols — and nothing else. There is
no title and no chevrons, because the calendar does not decide what your chrome looks like;
the text it does draw is unstyled, so it inherits your fonts and colors. Moving the binding
moves the month, so navigation is yours to trigger.

## Choose the calendar

Which calendar the view counts in is not an initializer parameter — it is SwiftUI's
`\.calendar` environment value, set the same way you would set it for a `DatePicker`:

```swift
var calendar = Calendar(identifier: .gregorian)
calendar.firstWeekday = 2                        // start weeks on Monday
calendar.locale = Locale(identifier: "fr_FR")    // "août 2026", "lun."

CalendarView(currentDay: $currentDay)
  .environment(\.calendar, calendar)
```

That single value decides the first weekday, the weekday symbols, the month title's
language, and the month lengths. Set it once high in your hierarchy and every calendar
below it follows. The view re-derives the bound day through it, so the grid and the title
can never disagree about which calendar they are in.

## Add a toolbar

``CalendarView/calendarToolbar(_:content:)`` puts your own views above or below the grid,
and hands them a ``CalendarProxy`` carrying the visible month and the actions that move
it:

```swift
CalendarView(currentDay: $currentDay)
  .calendarToolbar { month in
    HStack {
      Text(month.monthTitle)
        .font(.headline)

      Spacer()

      Button("Previous month", systemImage: "chevron.left", action: month.goToPreviousMonth)
        .labelStyle(.iconOnly)

      Button("Next month", systemImage: "chevron.right", action: month.goToNextMonth)
        .labelStyle(.iconOnly)
    }
  }
```

Everything a header might need is on the proxy: ``CalendarProxy/monthTitle``,
``CalendarProxy/monthName``, ``CalendarProxy/yearTitle``, ``CalendarProxy/year``,
``CalendarProxy/month``, the month's ``CalendarProxy/daysInMonth``, and actions from
``CalendarProxy/goToNextMonth()`` to ``CalendarProxy/go(to:)``. See <doc:Toolbars> for the
full picture, including stacking rows and putting one below the grid.

If you just want the conventional header, ``CalendarMonthHeader`` is one line:

```swift
CalendarView(currentDay: $currentDay)
  .calendarToolbar { CalendarMonthHeader($0) }
```

## Style the days

Real calendars need selection, badges, or availability. Pass a cell and you own the day
entirely — ``CalendarView`` only guarantees it a square with an equal share of the grid
width.

```swift
struct MonthPicker: View {
  @State private var currentDay = Calendar.autoupdatingCurrent.today
  @State private var selection: DateComponents?

  var body: some View {
    CalendarView(currentDay: $currentDay)
      .calendarCell { day in
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

The column headings are yours too, through ``CalendarView/calendarWeekdaySymbol(_:)``:

```swift
CalendarView(currentDay: $currentDay)
  .calendarWeekdaySymbol { weekday in
    Text(weekday.symbol.prefix(1))
      .font(.caption2.bold())
      .foregroundStyle(weekday.isWeekend ? .tertiary : .secondary)
  }
```

``CalendarView/calendarWeekdays(_:)`` takes a `Visibility`, so `.calendarWeekdays(.hidden)`
drops the row entirely. The same two modifiers exist on ``InlineCalendarView``.

Everything else about appearance — spacing, animation, dark surfaces — is in
<doc:Styling>.

## Bound the range

The calendar never refuses to navigate — your controls decide. Disable them by comparing
the visible month against your own limits:

```swift
let calendar = Calendar.autoupdatingCurrent

CalendarView(currentDay: $currentDay)
  .calendarToolbar { month in
    HStack {
      Button("Previous month", systemImage: "chevron.left", action: month.goToPreviousMonth)
        .disabled(month.firstDayOfMonth <= calendar.today.firstDayOfMonth)

      Text(month.monthTitle)

      Button("Next month", systemImage: "chevron.right", action: month.goToNextMonth)
        .disabled(month.month == 12)
    }
  }
```

## Show a single row of days

For a widget or a list row, ``InlineCalendarView`` draws just the days you give it, with
their weekday symbols above.

```swift
InlineCalendarView(visibleDays: Date.now.days(pastDays: 3, futureDays: 3))
  .calendarCell { date in
    Text(Calendar.current.component(.day, from: date).formatted(.number))
      .font(.system(size: 11, weight: .medium))
  }
  .frame(width: 156)
```

Days here have no default appearance — an inline calendar without a cell is a row of
weekday symbols over empty squares.

## Accessibility and localization

Everything the calendar displays comes from the calendar and its locale: weekday symbols,
day numbers, and every string on ``CalendarProxy`` are formatted, never hardcoded. Set the
`locale` of the calendar you put in the environment — or rely on the environment's
default — and it follows.

The package contains exactly two literal strings, the accessibility labels on
``CalendarMonthHeader``'s chevrons. They are `LocalizedStringResource` values resolved from
CalendarKit's own string catalog, so they translate independently of your app. English
ships in the box; adding a language means adding it to
`Sources/CalendarKit/Resources/Localizable.xcstrings` under the keys
`calendar.header.previousMonth` and `calendar.header.nextMonth`. Toolbars you build carry
your own strings, localized your own way.

Day cells are yours, and so is their accessibility. A cell built with
``CalendarView/calendarCell(_:)`` reads out as whatever it contains — a bare `Text("17")`
announces "17". Give it the full date and its state:

```swift
CalendarView(currentDay: $currentDay)
  .calendarCell { day in
    let date = day.date ?? .now

    Text(day.day?.formatted(.number) ?? "")
      .accessibilityLabel(Text(date.formatted(date: .complete, time: .omitted)))
      .accessibilityAddTraits(day == selection ? [.isButton, .isSelected] : .isButton)
  }
```

`Date.formatted(date:time:)` is locale-aware, so that label needs no strings of your own.

## Next steps

- <doc:Toolbars> — building chrome from the proxy.
- <doc:Styling> — inheritance, the replacement modifiers, spacing, and motion.
- <doc:WorkingWithDateComponents> — the date helpers the views are built on.
