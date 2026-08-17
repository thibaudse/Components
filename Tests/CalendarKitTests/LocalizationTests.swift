import Foundation
import Testing

@testable import CalendarKit

@Suite("Localization")
struct LocalizationTests {
  @Test("header accessibility labels resolve to their English strings")
  func headerLabels() {
    #expect(String(localized: .previousMonth) == "Previous month")
    #expect(String(localized: .nextMonth) == "Next month")
  }

  /// A lookup that misses falls back to its `defaultValue`, so resolving a string cannot
  /// tell us the catalog is wired up. Read the catalog itself instead, and check it
  /// carries the keys and values the code asks for.
  @Test("the string catalog matches the keys the package looks up")
  func catalogMatchesCode() throws {
    let catalogURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // CalendarKitTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // package root
      .appending(path: "Sources/CalendarKit/Resources/Localizable.xcstrings")

    struct Catalog: Decodable {
      struct Entry: Decodable {
        struct Localization: Decodable {
          struct Unit: Decodable {
            let value: String
          }

          let stringUnit: Unit
        }

        let localizations: [String: Localization]
      }

      let sourceLanguage: String
      let strings: [String: Entry]
    }

    let data = try Data(contentsOf: catalogURL)
    let catalog = try JSONDecoder().decode(Catalog.self, from: data)

    #expect(catalog.sourceLanguage == "en")
    #expect(catalog.strings.keys.sorted() == ["calendar.header.nextMonth", "calendar.header.previousMonth"])

    let expected = [
      "calendar.header.previousMonth": String(localized: .previousMonth),
      "calendar.header.nextMonth": String(localized: .nextMonth)
    ]

    for (key, value) in expected {
      #expect(catalog.strings[key]?.localizations["en"]?.stringUnit.value == value)
    }
  }
}
