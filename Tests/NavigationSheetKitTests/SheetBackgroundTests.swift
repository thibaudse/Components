import SwiftUI
import Testing

@testable import NavigationSheetKit

/// Which background the sheet draws, given that either end of the presentation may declare
/// one: the presenting view through the environment, a screen through a preference.
///
/// Worth pinning because the two arrive at different times — the presenter's is captured
/// before the sheet is on screen, a screen's a layout pass after — so "which wins" cannot be
/// read off the order they land in.
///
/// The winner is identified by **rendering** it. `AnyView` is not `Equatable`, so comparing
/// the resolved view against the two candidates is the only way to assert precedence rather
/// than merely assert that something resolved.
@MainActor
@Suite("Sheet background")
struct SheetBackgroundTests {
  @Test("Nothing declared leaves the system's own surface")
  func noBackground() {
    let model = NavigationSheetModel()

    #expect(model.resolvedBackground == nil)
    #expect(model.hasReplacedBackground == false)
  }

  @Test("The presenting view's background applies at every depth")
  func presenterBackgroundAppliesAtEveryDepth() {
    let model = NavigationSheetModel()
    model.chrome.background = AnyView(Color.black)

    #expect(render(model.resolvedBackground) == render(Color.black))

    model.currentDepth = 2

    #expect(render(model.resolvedBackground) == render(Color.black))
  }

  @Test("A screen's own background wins over the presenting view's")
  func screenBackgroundWins() {
    let model = NavigationSheetModel()
    model.chrome.background = AnyView(Color.black)
    model.screenBackgroundsByDepth[1] = AnyView(Color.orange)

    // At the root the screen has not spoken, so the presenter's stands.
    #expect(render(model.resolvedBackground) == render(Color.black))

    model.currentDepth = 1

    #expect(render(model.resolvedBackground) == render(Color.orange))
  }

  @Test("A screen alone replaces the background with no presenting view involved")
  func screenBackgroundWithoutPresenter() {
    let model = NavigationSheetModel()
    model.screenBackgroundsByDepth[0] = AnyView(Color.orange)

    #expect(render(model.resolvedBackground) == render(Color.orange))

    // A screen speaks for itself only: pushing past it falls back to the system surface.
    model.currentDepth = 1

    #expect(model.resolvedBackground == nil)
  }

  /// The view's pixels, as something comparable. `nil` for no view at all, which is a
  /// different answer from a view that renders nothing.
  private func render(_ view: (some View)?) -> Data? {
    guard let view else { return nil }

    let renderer = ImageRenderer(content: view.frame(width: 4, height: 4))
    renderer.scale = 1

    return renderer.uiImage?.pngData()
  }
}
