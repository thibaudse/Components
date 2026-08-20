import Foundation
import Testing

@testable import CalendarKit

private func gregorian(locale: String = "en_US", firstWeekday: Int = 1) -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC")!
  calendar.locale = Locale(identifier: locale)
  calendar.firstWeekday = firstWeekday
  return calendar
}

/// Records where a proxy asked the calendar to navigate.
private final class Destination {
  var day: DateComponents?
}

private func makeProxy(
  year: Int = 2026,
  month: Int = 8,
  day: Int = 17,
  calendar: Calendar = gregorian()
) -> (CalendarProxy, Destination) {
  let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
  let components = calendar.calendarDateComponents(from: date)
  let destination = Destination()

  let proxy = CalendarProxy(currentDay: components, calendar: calendar) { target in
    destination.day = target
  }

  return (proxy, destination)
}

@Suite("Proxy state")
struct ProxyStateTests {
  @Test("the visible month is exposed as numbers and as text")
  func visibleMonth() {
    let (proxy, _) = makeProxy()

    #expect(proxy.year == 2026)
    #expect(proxy.month == 8)
    #expect(proxy.monthTitle == "August 2026")
    #expect(proxy.monthName == "August")
    #expect(proxy.yearTitle == "2026")
  }

  @Test("titles follow the calendar's locale")
  func localizedTitles() {
    let (french, _) = makeProxy(calendar: gregorian(locale: "fr_FR"))
    let (japanese, _) = makeProxy(calendar: gregorian(locale: "ja_JP"))

    #expect(french.monthName.lowercased() == "août")
    #expect(french.monthTitle.contains("2026"))
    #expect(japanese.monthTitle.contains("2026"))
    #expect(japanese.monthTitle.contains("8"))
  }

  @Test("weekday symbols match the grid's columns")
  func weekdaySymbols() {
    let (sundayFirst, _) = makeProxy(calendar: gregorian(firstWeekday: 1))
    let (mondayFirst, _) = makeProxy(calendar: gregorian(firstWeekday: 2))

    #expect(sundayFirst.weekdaySymbols.first == "Sun")
    #expect(mondayFirst.weekdaySymbols.first == "Mon")
    #expect(mondayFirst.weekdaySymbols.count == 7)
  }

  @Test("the month's shape is exposed for toolbars to summarize")
  func monthShape() {
    let (proxy, _) = makeProxy()

    #expect(proxy.daysInMonth.count == 31)
    #expect(proxy.firstDayOfMonth.day == 1)
    #expect(proxy.lastDayOfMonth.day == 31)
    #expect(proxy.date == proxy.currentDay.date)
  }

  @Test("containsToday only holds for the month today falls in")
  func containsToday() {
    let calendar = gregorian()
    let today = calendar.today
    let destination = Destination()

    let current = CalendarProxy(currentDay: today, calendar: calendar) { destination.day = $0 }
    let other = CalendarProxy(currentDay: today.nextMonth, calendar: calendar) { destination.day = $0 }

    #expect(current.containsToday)
    #expect(!other.containsToday)
  }
}

@Suite("Proxy navigation")
struct ProxyNavigationTests {
  @Test("month actions move one month at a time")
  func monthActions() {
    let (forward, forwardDestination) = makeProxy()
    forward.goToNextMonth()
    #expect(forwardDestination.day?.month == 9)

    let (backward, backwardDestination) = makeProxy()
    backward.goToPreviousMonth()
    #expect(backwardDestination.day?.month == 7)
  }

  @Test("year actions keep the month and move the year")
  func yearActions() {
    let (forward, forwardDestination) = makeProxy()
    forward.goToNextYear()
    #expect(forwardDestination.day?.year == 2027)
    #expect(forwardDestination.day?.month == 8)

    let (backward, backwardDestination) = makeProxy()
    backward.goToPreviousYear()
    #expect(backwardDestination.day?.year == 2025)
    #expect(backwardDestination.day?.month == 8)
  }

  @Test("goToToday targets today in the view's calendar")
  func goToToday() {
    let calendar = gregorian()
    let (proxy, destination) = makeProxy(calendar: calendar)

    proxy.goToToday()

    #expect(destination.day?.day == calendar.component(.day, from: .now))
    #expect(destination.day?.calendar == calendar)
  }

  @Test("go(to:) resolves components that carry no calendar")
  func goToArbitraryDay() {
    let calendar = gregorian()
    let (proxy, destination) = makeProxy(calendar: calendar)

    proxy.go(to: DateComponents(year: 2027, month: 3, day: 9))

    #expect(destination.day?.year == 2027)
    #expect(destination.day?.month == 3)
    #expect(destination.day?.day == 9)
    // Resolved through the view's calendar, so the result can drive the grid.
    #expect(destination.day?.calendar == calendar)
    #expect(destination.day?.weekday != nil)
  }

  @Test("go(to:) keeps a calendar the caller already attached")
  func goToDayWithCalendar() {
    let other = gregorian(locale: "fr_FR", firstWeekday: 2)
    let (proxy, destination) = makeProxy()

    proxy.go(to: other.calendarDateComponents(from: other.date(from: DateComponents(year: 2027, month: 3, day: 9))!))

    #expect(destination.day?.calendar == other)
  }
}

@Suite("Weekday columns")
struct CalendarWeekdayTests {
  @Test("weekend columns are Saturday and Sunday, whatever the first weekday")
  func weekendColumns() {
    #expect(CalendarWeekday(symbol: "Sun", weekday: 1).isWeekend)
    #expect(CalendarWeekday(symbol: "Sat", weekday: 7).isWeekend)
    #expect(!CalendarWeekday(symbol: "Mon", weekday: 2).isWeekend)
    #expect(!CalendarWeekday(symbol: "Fri", weekday: 6).isWeekend)
  }
}

@Suite("Transition direction")
struct NavigationDirectionTests {
  @Test("direction follows the order of the two days")
  func direction() {
    let calendar = gregorian()
    let august = calendar.calendarDateComponents(from: calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))!)

    #expect(NavigationDirection(from: august, to: august.nextMonth) == .forward)
    #expect(NavigationDirection(from: august, to: august.previousMonth) == .backward)
    #expect(NavigationDirection(from: august, to: august.nextYear) == .forward)
    #expect(NavigationDirection(from: august, to: august.previousYear) == .backward)
    // A move that goes nowhere still yields a direction rather than nil.
    #expect(NavigationDirection(from: august, to: august) == .forward)
  }
}
