# Working with DateComponents

The date helpers the calendar views are built on, and the one rule they depend on.

## Overview

A day on a calendar is a year-month-day in some calendar, not an instant in time.
``CalendarView`` therefore speaks `DateComponents`, and CalendarKit extends
`DateComponents` with the arithmetic a calendar UI needs: stepping months, finding the
first weekday of a month, testing weekdays.

Every one of those helpers resolves through the calendar attached to the components. That
is the rule the whole package rests on:

> Important: Build components with ``Foundation/Calendar/today`` or
> ``Foundation/Calendar/calendarDateComponents(from:)``. Components created by hand —
> `DateComponents(year: 2026, month: 8, day: 17)` — carry no calendar, and the helpers
> return their input unchanged rather than guessing one.

```swift
let calendar = Calendar.autoupdatingCurrent

let today = calendar.today                              // ✅ carries the calendar
let picked = calendar.calendarDateComponents(from: date) // ✅ same
let handmade = DateComponents(year: 2026, month: 8, day: 17) // ⚠️ no calendar
```

`Calendar.calendarDateComponents(from:)` asks for *all* components, so `weekday`,
`weekOfMonth`, and the rest are populated too — helpers such as
``Foundation/DateComponents/isWeekend`` need them.

## Move through time

``Foundation/DateComponents/previousMonth`` and ``Foundation/DateComponents/nextMonth``
are what the header chevrons write back to your binding. Both go through the calendar, so
month lengths and leap years take care of themselves — the 31st of a month stepping into
a 30-day month clamps rather than overflowing.

```swift
currentDay = currentDay.nextMonth
currentDay = currentDay.previousDays(7)
currentDay = currentDay.nextDays()
```

``Foundation/DateComponents/with(year:month:day:)`` replaces individual fields and
re-derives everything else, so dependent components stay consistent:

```swift
let firstOfMonth = currentDay.with(day: 1)
let sameDayNextYear = currentDay.with(year: 2027)
```

## Lay out a month

These three drive the grid, and are useful whenever you build your own:

- ``Foundation/DateComponents/firstWeekdayOfMonth`` — how many blank cells precede day 1,
  honoring the calendar's `firstWeekday`.
- ``Foundation/DateComponents/daysInMonth`` — every day number in the month.
- ``Foundation/DateComponents/firstDayOfMonth`` and
  ``Foundation/DateComponents/lastDayOfMonth`` — the month's bounds, for clamping
  navigation or highlighting a range.

Labeling the columns needs the weekday symbols rotated to the calendar's first weekday,
which ``Foundation/Calendar/localizedShortWeekdaySymbols`` does:

```swift
Calendar(identifier: .gregorian).localizedShortWeekdaySymbols
// Sunday-first: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

var monday = Calendar(identifier: .gregorian)
monday.firstWeekday = 2
monday.localizedShortWeekdaySymbols
// ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
```

## Test weekdays

``Foundation/DateComponents/isMonday`` through ``Foundation/DateComponents/isSunday`` read
the `weekday` field, where Sunday is `1` no matter which day the calendar starts on.

```swift
CalendarView(currentDay: $currentDay)
  .withCellStyle { day in
    Text(day.day?.formatted(.number) ?? "")
      .foregroundStyle(day.isWeekend ? .secondary : .primary)
  }
```

``Foundation/DateComponents/isWeekend`` means Saturday or Sunday. For a locale's own
weekend definition, use `Calendar.isDateInWeekend(_:)` instead.

## Compare and sort

CalendarKit conforms `DateComponents` to `Comparable`, ordering by the date the components
resolve to:

```swift
if day < calendar.today { /* in the past */ }
selectedDays.sorted()
```

Two things to know:

- The conformance is retroactive, on a Foundation type. If another module you link also
  conforms `DateComponents` to `Comparable`, the duplicate is a build error and you should
  remove one. CalendarKit's views never use `<`, so removing this one breaks nothing.
- Equality is still Foundation's field-by-field `==`, not "same instant". Two values for
  the same day with different fields populated are unequal *and* unordered. Comparing
  values built the same way — all via ``Foundation/Calendar/calendarDateComponents(from:)``
  and the helpers above — keeps this consistent.

## Build a day range

``InlineCalendarView`` takes `Date` values, and
``Foundation/Date/days(pastDays:futureDays:calendar:)`` builds a contiguous run around a
date:

```swift
Date.now.days(pastDays: 3, futureDays: 3)  // 7 dates, today in the middle
```

## Topics

### Seeding components

- ``Foundation/Calendar/today``
- ``Foundation/Calendar/calendarDateComponents(from:)``

### Navigating

- ``Foundation/DateComponents/previousMonth``
- ``Foundation/DateComponents/nextMonth``
- ``Foundation/DateComponents/previousDays(_:)``
- ``Foundation/DateComponents/nextDays(_:)``
- ``Foundation/DateComponents/with(year:month:day:)``

### Laying out a month

- ``Foundation/DateComponents/firstWeekdayOfMonth``
- ``Foundation/DateComponents/daysInMonth``
- ``Foundation/DateComponents/firstDayOfMonth``
- ``Foundation/DateComponents/lastDayOfMonth``
- ``Foundation/Calendar/localizedShortWeekdaySymbols``
- ``Foundation/Calendar/lastWeekday``

### Testing weekdays

- ``Foundation/DateComponents/isMonday``
- ``Foundation/DateComponents/isTuesday``
- ``Foundation/DateComponents/isWednesday``
- ``Foundation/DateComponents/isThursday``
- ``Foundation/DateComponents/isFriday``
- ``Foundation/DateComponents/isSaturday``
- ``Foundation/DateComponents/isSunday``
- ``Foundation/DateComponents/isWeekend``

### Building day ranges

- ``Foundation/Date/days(pastDays:futureDays:calendar:)``
