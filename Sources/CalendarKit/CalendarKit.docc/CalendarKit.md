# ``CalendarKit``

Calendar views for SwiftUI that draw the chrome and leave the days to you.

## Overview

CalendarKit gives you two views and the date plumbing behind them:

- ``CalendarView`` — a month grid, and only the grid.
- ``InlineCalendarView`` — a single row of days for widgets and list rows.

Neither view decides what a day looks like, and neither draws chrome. Days come back to
you through ``CalendarView/calendarCell(_:)`` — return any view, a plain number, a ring, a
dot, a button. Titles and controls go on as toolbars through
``CalendarView/calendarToolbar(_:content:)``, each one handed a ``CalendarProxy`` with the
visible month and the actions that move it. What little the calendar draws for itself is
unstyled text, so your fonts and colors reach it through ordinary SwiftUI modifiers. There
is no theme, no design system, and no dependencies at all.

```swift
import CalendarKit
import SwiftUI

struct MonthView: View {
  @State private var currentDay = Calendar.autoupdatingCurrent.today

  var body: some View {
    CalendarView(currentDay: $currentDay)
      .calendarToolbar { month in
        HStack {
          Text(month.monthTitle)
          Spacer()
          Button("Next", action: month.goToNextMonth)
        }
      }
      .calendarCell { day in
        Text(day.day?.formatted(.number) ?? "")
          .foregroundStyle(day.isWeekend ? .secondary : .primary)
      }
  }
}
```

Month names, weekday symbols, and day numbers are formatted from the calendar's locale.
The only literal strings in the package are the two accessibility labels on the navigation
chevrons, which resolve from CalendarKit's own string catalog — see
<doc:GettingStarted#Accessibility-and-localization>.

### The calendar comes from the environment

Which calendar a view counts in is not a parameter — it is SwiftUI's `\.calendar`
environment value, set the way you would set it for `DatePicker` or a `Text(date)`:

```swift
var mondayFirst = Calendar(identifier: .gregorian)
mondayFirst.firstWeekday = 2
mondayFirst.locale = Locale(identifier: "fr_FR")

CalendarView(currentDay: $currentDay)
  .environment(\.calendar, mondayFirst)
```

That one value decides the first weekday, the weekday symbols, the month title's language,
and the month lengths. The views re-derive the bound day through it, so the grid, the
symbols, and the title can never disagree.

### Days are DateComponents, not Dates

``CalendarView`` works in `DateComponents` rather than `Date`. A day on a calendar is a
year-month-day in a particular calendar, not an instant, and components say that
directly — no time-of-day to normalize, no midnight-in-which-time-zone question.

```swift
@State private var currentDay = Calendar.current.today
```

The view accepts whatever you give it — components carrying a calendar or bare ones like
`DateComponents(year: 2026, month: 8, day: 17)` — because it re-reads them in the
environment's calendar either way. The `DateComponents` helpers in
<doc:WorkingWithDateComponents> do still need components that carry a calendar, so seed
state with ``Foundation/Calendar/today`` or
``Foundation/Calendar/calendarDateComponents(from:)`` if you use them yourself.

``InlineCalendarView`` takes `Date` values instead, because the days it shows usually
come from a range you already computed.

### The calendar is the content

A ``CalendarView`` is the grid. It has no built-in header, no navigation buttons, no
colors, and no padding of its own, so it composes like any other view: put it in a card, a
sheet, a popover, or a widget, and add exactly the chrome that context needs. Nothing is
hidden behind a style enum, because nothing is built in.

## Topics

### Essentials

- <doc:GettingStarted>
- ``CalendarView``
- ``InlineCalendarView``

### Chrome

- <doc:Toolbars>
- ``CalendarProxy``
- ``CalendarToolbarPlacement``
- ``CalendarMonthHeader``

### Appearance

- <doc:Styling>

### Dates

- <doc:WorkingWithDateComponents>
