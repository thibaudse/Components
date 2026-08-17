import SwiftUI

/// The colors, fonts, and metrics used by ``CalendarView`` and ``InlineCalendarView``.
///
/// CalendarKit ships without a design system of its own. Everything a calendar draws
/// — the month title, the weekday symbols, the fallback day numbers, the navigation
/// chevrons, and the spacing between them — is read from the theme in the environment.
///
/// Inject a theme with ``SwiftUICore/View/calendarTheme(_:)``:
///
/// ```swift
/// CalendarView(currentDay: $currentDay)
///   .calendarTheme(.dark)
/// ```
///
/// Or start from a preset and override a few values:
///
/// ```swift
/// var theme = CalendarTheme.default
/// theme.fonts.dayNumber = .custom("Georgia", size: 20)
/// theme.colors.control = .accentColor
/// ```
///
/// Cells rendered by ``CalendarView/withCellStyle(_:)`` are *not* themed — you own
/// their appearance completely. The theme only styles the chrome around them.
public struct CalendarTheme: Sendable {
  /// The colors used for calendar chrome.
  public var colors: Colors

  /// The fonts used for calendar chrome.
  public var fonts: Fonts

  /// The spacing and sizing used to lay out the calendar.
  public var metrics: Metrics

  /// Creates a theme.
  ///
  /// - Parameters:
  ///   - colors: The colors used for calendar chrome. Defaults to ``Colors/init(monthTitle:weekdaySymbol:dayNumber:control:controlDisabled:)`` defaults.
  ///   - fonts: The fonts used for calendar chrome.
  ///   - metrics: The spacing and sizing used to lay out the calendar.
  public init(
    colors: Colors = Colors(),
    fonts: Fonts = Fonts(),
    metrics: Metrics = Metrics()
  ) {
    self.colors = colors
    self.fonts = fonts
    self.metrics = metrics
  }

  /// A theme that adapts to light and dark appearance using the system's semantic colors.
  ///
  /// This is the theme used when no other theme is injected into the environment.
  public static let `default` = CalendarTheme()

  /// A theme for dark backgrounds: a white month title with dimmed secondary text.
  public static let dark = CalendarTheme(
    colors: Colors(
      monthTitle: .white,
      weekdaySymbol: .white.opacity(0.4),
      dayNumber: .white.opacity(0.4),
      control: .white,
      controlDisabled: .white.opacity(0.4)
    )
  )
}

public extension CalendarTheme {
  /// The colors used for calendar chrome.
  struct Colors: Sendable {
    /// The color of the month and year title in the header.
    public var monthTitle: Color

    /// The color of the weekday symbols above the grid (`MON`, `TUE`, …).
    public var weekdaySymbol: Color

    /// The color of the day numbers drawn when no cell style is provided.
    public var dayNumber: Color

    /// The color of the enabled navigation chevrons.
    public var control: Color

    /// The color of the navigation chevrons while they are disabled.
    public var controlDisabled: Color

    /// Creates a color set. Every parameter defaults to a semantic system color,
    /// so the calendar remains legible in both light and dark appearance.
    public init(
      monthTitle: Color = .primary,
      weekdaySymbol: Color = .secondary,
      dayNumber: Color = .secondary,
      control: Color = .primary,
      controlDisabled: Color = .secondary
    ) {
      self.monthTitle = monthTitle
      self.weekdaySymbol = weekdaySymbol
      self.dayNumber = dayNumber
      self.control = control
      self.controlDisabled = controlDisabled
    }
  }

  /// The fonts used for calendar chrome.
  struct Fonts: Sendable {
    /// The font of the month and year title in the header.
    public var monthTitle: Font

    /// The font of the weekday symbols above a ``CalendarView`` grid.
    public var weekdaySymbol: Font

    /// The font of the day numbers drawn when no cell style is provided.
    public var dayNumber: Font

    /// The font of the weekday symbols in an ``InlineCalendarView``, which is
    /// typically rendered much smaller than a full month grid.
    public var inlineWeekdaySymbol: Font

    /// Creates a font set.
    public init(
      monthTitle: Font = .system(size: 16, weight: .semibold),
      weekdaySymbol: Font = .system(size: 13, weight: .semibold),
      dayNumber: Font = .system(size: 20, weight: .medium),
      inlineWeekdaySymbol: Font = .system(size: 7, weight: .medium)
    ) {
      self.monthTitle = monthTitle
      self.weekdaySymbol = weekdaySymbol
      self.dayNumber = dayNumber
      self.inlineWeekdaySymbol = inlineWeekdaySymbol
    }
  }

  /// The spacing and sizing used to lay out the calendar.
  ///
  /// Day cells are always square and share the available width equally, so there is
  /// no cell size to configure — set the calendar's own frame instead.
  struct Metrics: Sendable {
    /// The vertical spacing between the header and the grid.
    public var headerSpacing: CGFloat

    /// The horizontal spacing between the title and the navigation chevrons.
    public var controlSpacing: CGFloat

    /// The point size of the navigation chevrons.
    public var controlSize: CGFloat

    /// The vertical spacing between the weekday symbols and the first row of days.
    public var weekdayRowSpacing: CGFloat

    /// The vertical spacing between rows of days.
    public var dayRowSpacing: CGFloat

    /// The insets applied around the whole ``CalendarView``.
    public var contentInsets: EdgeInsets

    /// The horizontal spacing between weekday symbols in an ``InlineCalendarView``.
    public var inlineWeekdaySpacing: CGFloat

    /// Creates a metrics set.
    public init(
      headerSpacing: CGFloat = 12,
      controlSpacing: CGFloat = 16,
      controlSize: CGFloat = 16,
      weekdayRowSpacing: CGFloat = 4,
      dayRowSpacing: CGFloat = 8,
      contentInsets: EdgeInsets = EdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12),
      inlineWeekdaySpacing: CGFloat = 2
    ) {
      self.headerSpacing = headerSpacing
      self.controlSpacing = controlSpacing
      self.controlSize = controlSize
      self.weekdayRowSpacing = weekdayRowSpacing
      self.dayRowSpacing = dayRowSpacing
      self.contentInsets = contentInsets
      self.inlineWeekdaySpacing = inlineWeekdaySpacing
    }
  }
}
