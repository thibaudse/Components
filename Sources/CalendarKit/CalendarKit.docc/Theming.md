# Theming

Match the calendar chrome to your design system.

## Overview

CalendarKit has no design system. Every color, font, and gap *it* draws comes from a
``CalendarTheme`` in the environment, so adopting the component costs one theme value
rather than a fork.

The theme's reach is deliberately small, because most of a calendar's appearance is
already yours: toolbars and cells you build are never themed. What is left is the weekday
row, the fallback day numbers, the spacing between rows — and ``CalendarMonthHeader``, if
you use it.

Two presets ship with it:

- ``CalendarTheme/default`` adapts to light and dark appearance using `Color.primary` and
  `Color.secondary`. This is what you get with no theme injected.
- ``CalendarTheme/dark`` is for dark backgrounds: a white title with secondary text at
  40% white.

```swift
CalendarView(currentDay: $currentDay)
  .calendarTheme(.dark)
```

## Build your own

A theme is three plain structs — ``CalendarTheme/Colors``, ``CalendarTheme/Fonts``, and
``CalendarTheme/Metrics`` — each with defaults for every field. Start from a preset and
change what differs:

```swift
extension CalendarTheme {
  static var myApp: CalendarTheme {
    var theme = CalendarTheme.dark
    theme.fonts.monthTitle = .custom("Inter", size: 16).weight(.semibold)
    theme.fonts.dayNumber = .custom("Inter", size: 20).weight(.medium)
    theme.colors.control = .accentColor
    theme.metrics.dayRowSpacing = 12
    return theme
  }
}
```

Then inject it once, as high in the hierarchy as you like — a theme applies to every
calendar below it, including ``InlineCalendarView``:

```swift
RootView()
  .calendarTheme(.myApp)
```

## Reach the theme from a cell or a toolbar

Cells built with ``CalendarView/calendarCell(_:)`` and toolbars built with
``CalendarView/calendarToolbar(_:content:)`` are deliberately unthemed: you own their
appearance. When you do want one to follow the calendar's own chrome, read the theme from
the environment:

```swift
struct DayCell: View {
  @Environment(\.calendarTheme) private var theme

  let day: DateComponents
  let isSelected: Bool

  var body: some View {
    Text(day.day?.formatted(.number) ?? "")
      .font(theme.fonts.dayNumber)
      .foregroundStyle(isSelected ? theme.colors.monthTitle : theme.colors.dayNumber)
  }
}
```

## What the theme covers

| Element | Color | Font |
| --- | --- | --- |
| Weekday symbols (month grid) | ``CalendarTheme/Colors/weekdaySymbol`` | ``CalendarTheme/Fonts/weekdaySymbol`` |
| Weekday symbols (inline) | ``CalendarTheme/Colors/weekdaySymbol`` | ``CalendarTheme/Fonts/inlineWeekdaySymbol`` |
| Default day numbers | ``CalendarTheme/Colors/dayNumber`` | ``CalendarTheme/Fonts/dayNumber`` |
| ``CalendarMonthHeader`` title | ``CalendarTheme/Colors/monthTitle`` | ``CalendarTheme/Fonts/monthTitle`` |
| ``CalendarMonthHeader`` chevrons | ``CalendarTheme/Colors/control``, ``CalendarTheme/Colors/controlDisabled`` | sized by ``CalendarTheme/Metrics/controlSize`` |

Layout is metrics only — ``CalendarTheme/Metrics/toolbarSpacing``,
``CalendarTheme/Metrics/weekdayRowSpacing``, ``CalendarTheme/Metrics/dayRowSpacing``,
``CalendarTheme/Metrics/controlSpacing``, ``CalendarTheme/Metrics/inlineWeekdaySpacing``,
and ``CalendarTheme/Metrics/contentInsets``.

Two things the theme deliberately does not do. There is no cell size to set: cells are
always square and split the available width evenly, so size a calendar with `frame`. And
``CalendarTheme/Metrics/contentInsets`` is zero by default — the calendar is the content,
so padding it is your call.

## Topics

### Theme values

- ``CalendarTheme``
- ``SwiftUICore/View/calendarTheme(_:)``
- ``SwiftUICore/EnvironmentValues/calendarTheme``
