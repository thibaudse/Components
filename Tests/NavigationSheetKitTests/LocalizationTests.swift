import Foundation
import Testing

@testable import NavigationSheetKit

@Suite("Localization")
struct LocalizationTests {
  @Test("navigation button accessibility labels resolve to their English strings")
  func navigationButtonLabels() {
    #expect(String(localized: .navigationBack) == "Back")
    #expect(String(localized: .navigationClose) == "Close")
  }

  /// A lookup that misses falls back to its `defaultValue`, so resolving a string cannot tell
  /// us the catalog is wired up. Read the catalog itself instead, and check it carries the keys
  /// and values the code asks for.
  @Test("the string catalog matches the keys the package looks up")
  func catalogMatchesCode() throws {
    let catalogURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // NavigationSheetKitTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // package root
      .appending(path: "Sources/NavigationSheetKit/Resources/Localizable.xcstrings")

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
    #expect(catalog.strings.keys.sorted() == ["navigationSheet.button.back", "navigationSheet.button.close"])

    let expected = [
      "navigationSheet.button.back": String(localized: .navigationBack),
      "navigationSheet.button.close": String(localized: .navigationClose)
    ]

    for (key, value) in expected {
      #expect(catalog.strings[key]?.localizations["en"]?.stringUnit.value == value)
    }
  }

  /// Xcode generates its own `LocalizedStringResource` accessors from a string catalog, named
  /// after the key with the separators stripped. A hand-written property with the same name
  /// compiles under `swift build` and then collides in Xcode, which is a confusing failure to
  /// hit later — so the keys are chosen to keep the two sets of names apart.
  @Test("the package's accessor names cannot collide with Xcode's generated ones")
  func accessorNamesAvoidGeneratedSymbols() {
    let generated = ["navigationSheet.button.back", "navigationSheet.button.close"].map { key in
      key.split(separator: ".").enumerated().map { index, part in
        index == 0 ? String(part) : part.capitalized
      }.joined()
    }

    #expect(generated == ["navigationSheetButtonBack", "navigationSheetButtonClose"])
    #expect(!generated.contains("navigationBack"))
    #expect(!generated.contains("navigationClose"))
  }
}
