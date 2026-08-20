# Toolbars

Build the chrome around the grid, from the calendar's own state.

## Overview

``CalendarView`` draws days. Titles, chevrons, year steppers, "Today" buttons, legends —
anything else — are views you supply through
``CalendarView/calendarToolbar(_:content:)``. Each toolbar closure receives a
``CalendarProxy``: a snapshot of the visible month plus the actions that move it.

```swift
CalendarView(currentDay: $currentDay)
  .calendarToolbar { month in
    HStack {
      Text(month.monthTitle)
      Spacer()
      Button("Next", action: month.goToNextMonth)
    }
  }
```

Two consequences worth knowing up front:

- The proxy is rebuilt on every update, so its values always describe the month on screen.
- Its actions write to the same binding you passed to
  ``CalendarView/init(currentDay:)``, so a toolbar button and a date picker
  elsewhere in your app move the calendar identically — and animate identically.

## What the proxy carries

| Reading the month | |
| --- | --- |
| ``CalendarProxy/currentDay`` | The bound day, fully populated, carrying its calendar |
| ``CalendarProxy/date`` | The same instant as a `Date` |
| ``CalendarProxy/year``, ``CalendarProxy/month`` | The visible year and month as numbers |
| ``CalendarProxy/monthTitle`` | "August 2026", formatted for the calendar's locale |
| ``CalendarProxy/monthName``, ``CalendarProxy/yearTitle`` | The two halves, for laying them out separately |
| ``CalendarProxy/weekdaySymbols`` | Column headings, already rotated to the first weekday |
| ``CalendarProxy/daysInMonth`` | Every day number in the month |
| ``CalendarProxy/firstDayOfMonth``, ``CalendarProxy/lastDayOfMonth`` | The month's bounds |
| ``CalendarProxy/containsToday`` | Whether today is in view |
| ``CalendarProxy/calendar`` | The calendar the grid resolved its layout with |
| ``CalendarProxy/animation`` | The calendar's own animation, to scope yours to the same curve |

| Moving it | |
| --- | --- |
| ``CalendarProxy/goToPreviousMonth()``, ``CalendarProxy/goToNextMonth()`` | One month at a time |
| ``CalendarProxy/goToPreviousYear()``, ``CalendarProxy/goToNextYear()`` | One year, same month |
| ``CalendarProxy/goToToday()`` | Back to today |
| ``CalendarProxy/go(to:)`` | Any day — a picker result, a search hit, a deep link |

## Stacking rows

Toolbars are additive. Apply the modifier more than once and each row is kept, in the
order applied, with the `toolbars` gap of
``CalendarView/calendarSpacing(rows:columns:weekdays:toolbars:)`` between them. Pass
``CalendarToolbarPlacement/below`` to put one under the grid:

```swift
CalendarView(currentDay: $currentDay)
  .calendarToolbar { month in
    HStack {
      Text(month.monthName).font(.title3.bold())
      Text(month.yearTitle).font(.title3).foregroundStyle(.secondary)
      Spacer()
    }
  }
  .calendarToolbar { month in
    Picker("Year", selection: .constant(month.year ?? 2026)) {
      // …your own year picker, calling month.go(to:) on change
    }
  }
  .calendarToolbar(.below) { month in
    HStack {
      Text("\(month.daysInMonth.count) days")
        .font(.footnote)
        .foregroundStyle(.secondary)

      Spacer()

      Button("Today", action: month.goToToday)
        .font(.footnote)
        .disabled(month.containsToday)
    }
  }
```

## A year stepper

Because the proxy exposes year navigation directly, a two-level header is a handful of
lines:

```swift
.calendarToolbar { month in
  HStack(spacing: 16) {
    Button("Previous year", systemImage: "chevron.left.2", action: month.goToPreviousYear)
    Text(month.yearTitle).monospacedDigit()
    Button("Next year", systemImage: "chevron.right.2", action: month.goToNextYear)
  }
  .labelStyle(.iconOnly)
}
```

## Jumping to a specific day

``CalendarProxy/go(to:)`` accepts any `DateComponents`, including hand-built ones with no
calendar attached — it resolves them against the calendar the view is using, so the result
can always drive the grid:

```swift
.calendarToolbar(.below) { month in
  Button("Jump to New Year") {
    month.go(to: DateComponents(year: (month.year ?? 2026) + 1, month: 1, day: 1))
  }
}
```

## Styling your toolbars

Toolbars are your views, so they follow your design system — nothing in CalendarKit styles
them. They do sit inside the calendar's view tree, so anything you apply to the calendar as
a whole reaches them too:

```swift
CalendarView(currentDay: $currentDay)
  .calendarToolbar { month in
    Text(month.monthTitle)
  }
  .font(.callout)          // reaches the toolbar and the grid alike
  .foregroundStyle(.white)
```

``CalendarMonthHeader`` is built exactly this way — unstyled text and plain `Button`s,
inheriting everything — and is worth reading as a worked example, or using directly when
the conventional header is all you need.

## Topics

### Building chrome

- ``CalendarView/calendarToolbar(_:content:)``
- ``CalendarProxy``
- ``CalendarToolbarPlacement``
- ``CalendarMonthHeader``
