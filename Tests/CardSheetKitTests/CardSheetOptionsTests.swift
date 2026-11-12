#if os(iOS)
import Testing

@testable import CardSheetKit

// The card-sheet modifiers each set one field of one preference. `.preference` would replace the
// whole value, so a second modifier erased the first; they merge instead.
struct CardSheetOptionsTests {
  @Test func modifiersSettingDifferentFieldsKeepEachOther() {
    let snapping = CardSheetOptions(snapping: .always)
    let peek = CardSheetOptions(neighbourPeek: 24)

    let merged = snapping.merged(with: peek)

    #expect(merged == CardSheetOptions(snapping: .always, neighbourPeek: 24))
  }

  @Test func theLaterValueOfAFieldWins() {
    let first = CardSheetOptions(snapping: .always, expandsToFullScreen: false)
    let second = CardSheetOptions(snapping: .never)

    let merged = first.merged(with: second)

    #expect(merged.snapping == .never)
    #expect(merged.expandsToFullScreen == false)
  }

  @Test func anUnsetFieldStaysUnset() {
    let merged = CardSheetOptions().merged(with: CardSheetOptions(expandsToFullScreen: true))

    #expect(merged.snapping == nil)
    #expect(merged.neighbourPeek == nil)
  }

  @Test func siblingsReduceIntoOneValue() {
    var value = CardSheetOptionsKey.defaultValue

    CardSheetOptionsKey.reduce(value: &value) { CardSheetOptions(snapping: .never) }
    CardSheetOptionsKey.reduce(value: &value) { CardSheetOptions(neighbourPeek: 0) }

    #expect(value == CardSheetOptions(snapping: .never, neighbourPeek: 0))
  }
}
#endif
