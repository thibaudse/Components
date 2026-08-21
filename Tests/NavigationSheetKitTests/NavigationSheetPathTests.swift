import Testing

@testable import NavigationSheetKit

@Suite("NavigationSheetPath")
struct NavigationSheetPathTests {
  private enum Route: Hashable, Sendable {
    case first
    case second
    case third
  }

  @Test("A new path is empty")
  func emptyByDefault() {
    let path = NavigationSheetPath()

    #expect(path.isEmpty)
    #expect(path.count == 0)
    #expect(path.last == nil)
  }

  @Test("Initializing from a sequence keeps its order")
  func initFromSequence() {
    let path = NavigationSheetPath([Route.first, .second, .third])

    #expect(path.count == 3)
    #expect(path.last == AnyHashable(Route.third))
    #expect(path.identifiedElements.map(\.depth) == [1, 2, 3])
  }

  @Test("Appending pushes onto the end")
  func appendPushes() {
    var path = NavigationSheetPath()

    path.append(Route.first)
    path.append(Route.second)

    #expect(path.count == 2)
    #expect(path.last == AnyHashable(Route.second))
  }

  @Test("Values of mixed types coexist on one path")
  func mixedElementTypes() {
    var path = NavigationSheetPath()

    path.append(Route.first)
    path.append("a string")
    path.append(42)

    #expect(path.count == 3)
    #expect(path.last == AnyHashable(42))
  }

  @Test("Depth counts up from one, whichever way the path was built")
  func depthsAreSequential() {
    var path = NavigationSheetPath([Route.first])

    path.append(Route.second)
    path.append(Route.third)

    #expect(path.identifiedElements.map(\.depth) == [1, 2, 3])
  }

  @Test("Every entry gets its own identity, even for equal values")
  func identitiesAreUnique() {
    var path = NavigationSheetPath()

    path.append(Route.first)
    path.append(Route.first)

    let ids = Set(path.identifiedElements.map(\.id))
    #expect(ids.count == 2)
  }

  @Test("Removing pops from the end")
  func removeLastPops() {
    var path = NavigationSheetPath([Route.first, .second, .third])

    path.removeLast()

    #expect(path.count == 2)
    #expect(path.last == AnyHashable(Route.second))
  }

  @Test("Removing several pops several")
  func removeLastCountPops() {
    var path = NavigationSheetPath([Route.first, .second, .third])

    path.removeLast(2)

    #expect(path.count == 1)
    #expect(path.last == AnyHashable(Route.first))
  }

  // A pop past the root is a programmer error the sheet has to survive: it can arrive from a
  // back button and a dismiss racing each other. It clamps and logs rather than trapping.
  @Test("Removing more than the path holds empties it instead of trapping")
  func removeLastClampsAboveCount() {
    var path = NavigationSheetPath([Route.first, .second])

    path.removeLast(10)

    #expect(path.isEmpty)
  }

  @Test("Removing from an empty path is a no-op")
  func removeLastOnEmptyPath() {
    var path = NavigationSheetPath()

    path.removeLast()

    #expect(path.isEmpty)
  }

  @Test("A negative count changes nothing")
  func removeLastRejectsNegativeCount() {
    var path = NavigationSheetPath([Route.first, .second])

    path.removeLast(-3)

    #expect(path.count == 2)
  }

  @Test("Removing zero changes nothing")
  func removeLastZero() {
    var path = NavigationSheetPath([Route.first, .second])

    path.removeLast(0)

    #expect(path.count == 2)
  }

  @Test("Removing all empties the path")
  func removeAllEmpties() {
    var path = NavigationSheetPath([Route.first, .second, .third])

    path.removeAll()

    #expect(path.isEmpty)
    #expect(path.last == nil)
  }

  // Equality is by element, not by identity — otherwise two paths built the same way would
  // never compare equal, and the sheet animates on `value: path`.
  @Test("Paths with the same elements are equal, whatever their identities")
  func equalityIgnoresIdentity() {
    let built = NavigationSheetPath([Route.first, .second])
    var appended = NavigationSheetPath()
    appended.append(Route.first)
    appended.append(Route.second)

    #expect(built == appended)
  }

  @Test("Order matters to equality")
  func equalityRespectsOrder() {
    let forward = NavigationSheetPath([Route.first, .second])
    let backward = NavigationSheetPath([Route.second, .first])

    #expect(forward != backward)
  }

  @Test("A push makes a path unequal to what it was")
  func appendBreaksEquality() {
    let original = NavigationSheetPath([Route.first])
    var pushed = original
    pushed.append(Route.second)

    #expect(original != pushed)
  }

  @Test("A path is a value: copies do not share storage")
  func copiesAreIndependent() {
    var original = NavigationSheetPath([Route.first])
    var copy = original

    copy.append(Route.second)
    original.append(Route.third)

    #expect(original.last == AnyHashable(Route.third))
    #expect(copy.last == AnyHashable(Route.second))
    #expect(original.count == 2)
    #expect(copy.count == 2)
  }
}
