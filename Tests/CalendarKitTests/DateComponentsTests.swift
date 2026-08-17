import Foundation
import Testing

@testable import CalendarKit

/// A fixed calendar so the date math is tested independently of the host's locale.
private func gregorian(firstWeekday: Int = 1) -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC")!
  calendar.locale = Locale(identifier: "en_US_POSIX")
  calendar.firstWeekday = firstWeekday
  return calendar
}

private func day(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar = gregorian()) -> DateComponents {
  let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
  return calendar.calendarDateComponents(from: date)
}

@Suite("Seeding components")
struct SeedingTests {
  @Test("calendarDateComponents populates the fields the views rely on")
  func populatesAllFields() {
    let components = day(2026, 8, 17)

    #expect(components.calendar != nil)
    #expect(components.year == 2026)
    #expect(components.month == 8)
    #expect(components.day == 17)
    #expect(components.weekday == 2)  // a Monday
    #expect(components.weekOfMonth != nil)
  }

  @Test("today carries its calendar and resolves to now")
  func todayCarriesCalendar() {
    let calendar = gregorian()
    let today = calendar.today

    #expect(today.calendar == calendar)
    #expect(today.day == calendar.component(.day, from: .now))
  }

  @Test("helpers pass through components that carry no calendar")
  func passesThroughWithoutCalendar() {
    let bare = DateComponents(year: 2026, month: 8, day: 17)

    #expect(bare.nextMonth == bare)
    #expect(bare.previousMonth == bare)
    #expect(bare.with(day: 1) == bare)
    #expect(bare.daysInMonth.isEmpty)
    #expect(bare.firstWeekdayOfMonth == 0)
  }
}

@Suite("Month layout")
struct MonthLayoutTests {
  @Test("firstWeekdayOfMonth counts the blank cells before day 1")
  func blankLeadingCells() {
    // 1 August 2026 is a Saturday.
    #expect(day(2026, 8, 17, calendar: gregorian(firstWeekday: 1)).firstWeekdayOfMonth == 6)
    #expect(day(2026, 8, 17, calendar: gregorian(firstWeekday: 2)).firstWeekdayOfMonth == 5)

    // 1 February 2026 is a Sunday: flush left in a Sunday-first calendar.
    #expect(day(2026, 2, 10, calendar: gregorian(firstWeekday: 1)).firstWeekdayOfMonth == 0)
    #expect(day(2026, 2, 10, calendar: gregorian(firstWeekday: 2)).firstWeekdayOfMonth == 6)
  }

  @Test("daysInMonth follows the calendar, leap years included")
  func daysInMonth() {
    #expect(day(2026, 8, 17).daysInMonth == Array(1...31))
    #expect(day(2026, 4, 1).daysInMonth.count == 30)
    #expect(day(2025, 2, 1).daysInMonth.count == 28)
    #expect(day(2024, 2, 1).daysInMonth.count == 29)
  }

  @Test("firstDayOfMonth and lastDayOfMonth bound the month")
  func monthBounds() {
    let august = day(2026, 8, 17)

    #expect(august.firstDayOfMonth.day == 1)
    #expect(august.firstDayOfMonth.month == 8)
    #expect(august.lastDayOfMonth.day == 31)
    #expect(august.lastDayOfMonth.month == 8)

    let february = day(2024, 2, 15)
    #expect(february.lastDayOfMonth.day == 29)
    #expect(february.lastDayOfMonth.month == 2)
  }

  @Test("short weekday symbols rotate to the calendar's first weekday")
  func rotatedWeekdaySymbols() {
    let sundayFirst = gregorian(firstWeekday: 1).localizedShortWeekdaySymbols
    let mondayFirst = gregorian(firstWeekday: 2).localizedShortWeekdaySymbols

    #expect(sundayFirst == ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
    #expect(mondayFirst == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
  }

  @Test("lastWeekday is the day before the calendar's first")
  func lastWeekday() {
    #expect(gregorian(firstWeekday: 1).lastWeekday == 7)
    #expect(gregorian(firstWeekday: 2).lastWeekday == 1)
  }
}

@Suite("Navigation")
struct NavigationTests {
  @Test("months step across year boundaries")
  func acrossYearBoundary() {
    let december = day(2026, 12, 15)
    #expect(december.nextMonth.year == 2027)
    #expect(december.nextMonth.month == 1)

    let january = day(2026, 1, 15)
    #expect(january.previousMonth.year == 2025)
    #expect(january.previousMonth.month == 12)
  }

  @Test("stepping into a shorter month clamps the day")
  func clampsShortMonths() {
    let januaryThirtyFirst = day(2026, 1, 31)
    let february = januaryThirtyFirst.nextMonth

    #expect(february.month == 2)
    #expect(february.day == 28)
  }

  @Test("day navigation crosses month boundaries")
  func dayNavigation() {
    let first = day(2026, 8, 1)

    #expect(first.previousDays().month == 7)
    #expect(first.previousDays().day == 31)
    #expect(first.nextDays(31).month == 9)
    #expect(first.nextDays(7).day == 8)
  }

  @Test("navigation keeps the calendar attached")
  func keepsCalendar() {
    let calendar = gregorian(firstWeekday: 2)
    let components = day(2026, 8, 17, calendar: calendar)

    #expect(components.nextMonth.calendar == calendar)
    #expect(components.previousDays(3).calendar == calendar)
  }

  @Test("with(year:month:day:) re-derives dependent fields")
  func withFields() {
    let august = day(2026, 8, 17)  // Monday
    let firstOfMonth = august.with(day: 1)

    #expect(firstOfMonth.day == 1)
    #expect(firstOfMonth.month == 8)
    #expect(firstOfMonth.weekday == 7)  // Saturday
    #expect(august.with(year: 2027).year == 2027)
    #expect(august.with(month: 9).month == 9)
  }
}

@Suite("Weekdays")
struct WeekdayTests {
  @Test("weekday flags match the day of the week")
  func weekdayFlags() {
    // 17–23 August 2026 is a Monday-to-Sunday week.
    #expect(day(2026, 8, 17).isMonday)
    #expect(day(2026, 8, 18).isTuesday)
    #expect(day(2026, 8, 19).isWednesday)
    #expect(day(2026, 8, 20).isThursday)
    #expect(day(2026, 8, 21).isFriday)
    #expect(day(2026, 8, 22).isSaturday)
    #expect(day(2026, 8, 23).isSunday)
  }

  @Test("weekend covers Saturday and Sunday only")
  func weekend() {
    #expect(day(2026, 8, 22).isWeekend)
    #expect(day(2026, 8, 23).isWeekend)
    #expect(!day(2026, 8, 21).isWeekend)
    #expect(!day(2026, 8, 24).isWeekend)
  }

  @Test("flags are independent of the calendar's first weekday")
  func independentOfFirstWeekday() {
    #expect(day(2026, 8, 17, calendar: gregorian(firstWeekday: 2)).isMonday)
    #expect(day(2026, 8, 17, calendar: gregorian(firstWeekday: 1)).isMonday)
  }
}

@Suite("Comparing")
struct ComparableTests {
  @Test("components order chronologically")
  func chronologicalOrder() {
    #expect(day(2026, 8, 17) < day(2026, 8, 18))
    #expect(day(2025, 12, 31) < day(2026, 1, 1))
    #expect(!(day(2026, 8, 18) < day(2026, 8, 17)))
    #expect(!(day(2026, 8, 17) < day(2026, 8, 17)))
  }

  @Test("components sort")
  func sorting() {
    let days = [day(2026, 8, 20), day(2026, 8, 17), day(2026, 9, 1)]

    #expect(days.sorted().map(\.day) == [17, 20, 1])
  }

  @Test("components that cannot form a date are unordered")
  func unorderedWithoutDate() {
    let bare = DateComponents(year: 2026, month: 8, day: 17)
    let real = day(2026, 8, 17)

    #expect(!(bare < real))
    #expect(!(real < bare))
    #expect(!(bare < bare))
  }
}

@Suite("Day ranges")
struct DayRangeTests {
  @Test("days returns a contiguous ascending run")
  func contiguousRun() {
    let calendar = gregorian()
    let anchor = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))!
    let days = anchor.days(pastDays: 3, futureDays: 2, calendar: calendar)

    #expect(days.count == 6)
    #expect(days.map { calendar.component(.day, from: $0) } == [14, 15, 16, 17, 18, 19])
    #expect(days == days.sorted())
  }

  @Test("days crosses a month boundary")
  func crossesMonth() {
    let calendar = gregorian()
    let anchor = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
    let days = anchor.days(pastDays: 1, futureDays: 1, calendar: calendar)

    #expect(days.map { calendar.component(.month, from: $0) } == [8, 8, 9])
  }

  @Test("negative bounds return nothing")
  func negativeBounds() {
    #expect(Date.now.days(pastDays: -1, futureDays: 3).isEmpty)
    #expect(Date.now.days(pastDays: 3, futureDays: -1).isEmpty)
    #expect(Date.now.days(pastDays: 0, futureDays: 0).count == 1)
  }
}
