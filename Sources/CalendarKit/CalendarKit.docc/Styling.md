# Styling

The calendar places days. Everything about how they look is yours.

## Overview

CalendarKit has no theme, no style protocol, and no appearance enum. It draws unstyled
text, which means two things:

1. **Ordinary SwiftUI modifiers reach it.** `font(_:)`, `foregroundStyle(_:)`,
   `fontWeight(_:)`, `tint(_:)`, `environment(_:_:)` — applied to a ``CalendarView``, they
   flow into the day numbers and weekday symbols like they would into any `Text`.
2. **Anything you need to replace has a modifier.** Days, column headings, and chrome are
   each substitutable outright, and the gaps between them are settable.

```swift
CalendarView(currentDay: $currentDay)
  .font(.system(size: 17, weight: .medium, design: .rounded))
  .foregroundStyle(.primary)
```

That is the whole styling story for a calendar that just needs to match your app's text.

## Replace what it draws

| Part | Modifier | Receives |
| --- | --- | --- |
| A day | ``CalendarView/calendarCell(_:)`` | `DateComponents`, carrying its calendar |
| A column heading | ``CalendarView/calendarWeekdaySymbol(_:)`` | ``CalendarWeekday`` |
| The heading row | ``CalendarView/calendarWeekdays(_:)`` | a `Visibility` |
| Chrome above or below | ``CalendarView/calendarToolbar(_:content:)`` | ``CalendarProxy`` |

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
      .background {
        if day.isWeekend {
          Circle().fill(.quaternary)
        }
      }
  }
```

Cells are laid out in squares that share the width equally, so size content relative to
that square. There is no cell size to set: give the calendar a `frame(_:)` and the squares
follow.

## Set the gaps

``CalendarView/calendarSpacing(rows:columns:weekdays:toolbars:)`` covers every gap the
calendar leaves inside itself. Omitted values keep their defaults.

```swift
CalendarView(currentDay: $currentDay)
  .calendarSpacing(rows: 12, columns: 4, weekdays: 8, toolbars: 16)
```

| Parameter | Default | Gap |
| --- | --- | --- |
| `rows` | 8 | Between rows of days |
| `columns` | 0 | Between columns, in the heading row and the grid alike |
| `weekdays` | 4 | Between the heading row and the first row of days |
| `toolbars` | 12 | Between toolbar rows, and between a toolbar and the grid |

The calendar adds no padding around itself — it is content, so `padding(_:)` is yours to
apply.

## Control the motion

Month changes animate with `.snappy(duration: 0.3)` and a directional slide that blurs and
fades. Both halves are replaceable:

```swift
CalendarView(currentDay: $currentDay)
  .calendarAnimation(.bouncy)                    // or nil, for instant changes
  .calendarTransition { direction in
    .push(from: direction == .forward ? .trailing : .leading)
  }
```

``CalendarView/calendarTransition(_:)`` receives a ``CalendarNavigationDirection``, so an
asymmetric transition can be built either way round. The direction is inferred from the
days themselves, which means it is correct whether a toolbar button moved the binding or
something else in your app did.

## Rendering

The grid is flattened into a single offscreen layer with `drawingGroup()` before it is
drawn. That is a measurable win on the month transition, which animates every cell at
once, so it is on by default.

The trade-off is that your cells are rasterized along with everything else, which some
effects cannot survive — a `Material` background, vibrancy, or a shadow that falls outside
a cell's bounds. Turn it off for those:

```swift
CalendarView(currentDay: $currentDay)
  .calendarCell { day in
    DayCell(day: day)      // draws a .regularMaterial background
  }
  .calendarDrawingGroup(false)
```

``InlineCalendarView/calendarDrawingGroup(_:)`` does the same for the inline row.

## Dark surfaces

There is no dark preset to opt into, because there is nothing to preset: state the colors
you want, or let them inherit.

```swift
CalendarView(currentDay: $currentDay)
  .calendarToolbar { month in
    Text(month.monthTitle).fontWeight(.semibold)
  }
  .calendarWeekdaySymbol { weekday in
    Text(weekday.symbol.localizedUppercase)
      .font(.caption2)
      .foregroundStyle(.white.opacity(0.4))
  }
  .foregroundStyle(.white)
  .padding()
  .background(Color.black)
```

## Sharing a style across a codebase

Since styling is plain SwiftUI, factor it out the way you would anything else — a wrapper
view, or a `ViewModifier` if you want it to compose:

```swift
struct AppCalendarStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .font(.brandBody)
      .foregroundStyle(.brandInk)
      .padding(.horizontal, 12)
  }
}

extension View {
  func appCalendarStyle() -> some View {
    modifier(AppCalendarStyle())
  }
}
```

Modifiers that replace content — cells, headings, toolbars — return `CalendarView` rather
than `some View`, so wrap the calendar in a view of your own when you want to reuse a
whole configuration:

```swift
struct AppCalendar: View {
  @Binding var currentDay: DateComponents

  var body: some View {
    CalendarView(currentDay: $currentDay)
      .calendarToolbar { CalendarMonthHeader($0) }
      .calendarCell { DayCell(day: $0) }
      .appCalendarStyle()
  }
}
```

## Topics

### Replacing what it draws

- ``CalendarView/calendarCell(_:)``
- ``CalendarView/calendarWeekdaySymbol(_:)``
- ``CalendarView/calendarWeekdays(_:)``
- ``CalendarWeekday``

### Laying it out

- ``CalendarView/calendarSpacing(rows:columns:weekdays:toolbars:)``

### Animating month changes

- ``CalendarView/calendarAnimation(_:)``
- ``CalendarView/calendarTransition(_:)``
- ``CalendarNavigationDirection``

### Tuning rendering

- ``CalendarView/calendarDrawingGroup(_:)``
- ``InlineCalendarView/calendarDrawingGroup(_:)``
