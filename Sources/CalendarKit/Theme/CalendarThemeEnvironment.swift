import SwiftUI

private struct CalendarThemeKey: EnvironmentKey {
  static let defaultValue = CalendarTheme.default
}

public extension EnvironmentValues {
  /// The theme used by the calendars in this part of the view hierarchy.
  ///
  /// Read this when building a custom cell style that should follow the same
  /// colors and fonts as the surrounding calendar chrome:
  ///
  /// ```swift
  /// struct DayCell: View {
  ///   @Environment(\.calendarTheme) private var theme
  ///   let day: Int
  ///
  ///   var body: some View {
  ///     Text(day.formatted(.number))
  ///       .font(theme.fonts.dayNumber)
  ///   }
  /// }
  /// ```
  var calendarTheme: CalendarTheme {
    get { self[CalendarThemeKey.self] }
    set { self[CalendarThemeKey.self] = newValue }
  }
}

public extension View {
  /// Sets the theme used by every calendar in this view hierarchy.
  ///
  /// - Parameter theme: The theme to apply. Use ``CalendarTheme/default`` for a
  ///   calendar that adapts to light and dark appearance, ``CalendarTheme/dark``
  ///   for dark backgrounds, or a value you built yourself.
  func calendarTheme(_ theme: CalendarTheme) -> some View {
    environment(\.calendarTheme, theme)
  }
}
