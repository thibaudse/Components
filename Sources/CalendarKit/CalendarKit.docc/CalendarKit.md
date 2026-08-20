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
themed through ``CalendarTheme``, so the component carries no design system of its own and
no dependencies at all.

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

### Days are DateComponents, not Dates

``CalendarView`` works in `DateComponents` rather than `Date`. A day on a calendar is a
year-month-day in a particular calendar, not an instant, and components say that
directly — no time-of-day to normalize, no midnight-in-which-time-zone question.

The one rule that follows: components must carry their calendar. Seed state with
``Foundation/Calendar/today`` (or ``Foundation/Calendar/calendarDateComponents(from:)``)
and every helper in this package resolves correctly.

```swift
@State private var currentDay = Calendar.autoupdatingCurrent.today
```

Bare components such as `DateComponents(year: 2026, month: 8, day: 17)` carry no
calendar. ``CalendarView`` falls back to the calendar passed to
``CalendarView/init(currentDay:calendar:)`` in that case, but the date helpers in
<doc:WorkingWithDateComponents> return their input unchanged, so prefer seeded values.

``InlineCalendarView`` takes `Date` values instead, because the days it shows usually
come from a range you already computed.

### The calendar is the content

A ``CalendarView`` is the grid. It has no built-in header, no navigation buttons, and no
padding of its own, so it composes like any other view: put it in a card, a sheet, a
popover, or a widget, and add exactly the chrome that context needs. Nothing is hidden
behind a style enum, because nothing is built in.

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

- <doc:Theming>
- ``CalendarTheme``

### Dates

- <doc:WorkingWithDateComponents>
