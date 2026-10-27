import Testing

@testable import MultishellAppCore

@Suite
struct QuickSwitcherResultsScrollTargetTests {
  private static let first = QuickSwitcherTarget.command(path: ["Edit", "Copy"])
  private static let second = QuickSwitcherTarget.command(path: ["Edit", "Paste"])
  private static let third = QuickSwitcherTarget.command(path: ["View", "Files"])
  private static let fourth = QuickSwitcherTarget.command(path: ["View", "Git"])

  private static func results(
    selected: QuickSwitcherTarget?,
    text: String = "",
    arrowPresses: Int = 0,
    isSelectedByPointer: Bool = false,
    listing rows: [QuickSwitcherTarget] = [first, second, third, fourth],
  ) -> QuickSwitcherResults {
    func items(_ targets: [QuickSwitcherTarget]) -> [QuickSwitcherItem] {
      targets.filter(rows.contains).map { target in
        QuickSwitcherItem(target: target, kind: .command, title: "", location: "")
      }
    }
    return QuickSwitcherResults(
      sections: [
        QuickSwitcherSection(kind: .places, items: items([first, second])),
        QuickSwitcherSection(kind: .commands, items: items([third, fourth])),
      ],
      selected: selected,
      isSelectedByPointer: isSelectedByPointer,
      arrowPresses: arrowPresses,
      query: QuickSwitcherResults.Query(scope: .all, text: text),
    )
  }

  @Test func theArrowsRowGoingBackToTheFirstScrollsToTheTop() {
    let previous = Self.results(selected: Self.fourth, arrowPresses: 3)

    let results = Self.results(
      selected: Self.fourth,
      arrowPresses: 3,
      listing: [Self.first, Self.second, Self.third],
    )

    #expect(results.scrollTarget(after: previous) == .top)
  }

  @Test func aRowThePointerChoseGoingLeavesTheScrollUnderThePointer() {
    let previous = Self.results(selected: Self.fourth, isSelectedByPointer: true)

    let results = Self.results(
      selected: Self.fourth,
      isSelectedByPointer: true,
      listing: [Self.first, Self.second, Self.third],
    )

    #expect(results.scrollTarget(after: previous) == nil)
  }

  @Test func aSelectionLostAlreadyScrollsOnlyOnce() {
    let previous = Self.results(selected: Self.fourth, listing: [Self.second, Self.third])

    let results = Self.results(
      selected: Self.fourth,
      listing: [Self.first, Self.second, Self.third],
    )

    #expect(results.scrollTarget(after: previous) == nil)
  }

  @Test func upOnTheFirstRowShowsItsSectionTitleToo() {
    let previous = Self.results(selected: Self.first, arrowPresses: 1)

    let results = Self.results(selected: Self.first, arrowPresses: 2)

    #expect(results.scrollTarget(after: previous) == .top)
  }

  @Test func anArrowPressedAtTheEndBringsItsRowBackIntoView() {
    let previous = Self.results(selected: Self.fourth, arrowPresses: 3)

    let results = Self.results(selected: Self.fourth, arrowPresses: 4)

    #expect(results.scrollTarget(after: previous) == .row(Self.fourth))
  }

  @Test func newTextScrollsToTheTopThoughTheFirstRowStaysSelected() {
    let results = Self.results(selected: nil, text: "a")

    #expect(results.scrollTarget(after: Self.results(selected: nil)) == .top)
  }

  @Test func aSelectionTheArrowsDidNotMoveLeavesTheScrollWhereItIs() {
    let results = Self.results(selected: nil)

    #expect(results.scrollTarget(after: Self.results(selected: Self.third)) == nil)
  }

  @Test func arrowsDownScrollToTheRowAlone() {
    let results = Self.results(selected: Self.third, arrowPresses: 1)

    #expect(results.scrollTarget(after: Self.results(selected: Self.second)) == .row(Self.third))
  }

  @Test func arrowsUpOntoARowStartingNoSectionScrollToTheRowAlone() {
    let results = Self.results(selected: Self.second, arrowPresses: 1)

    #expect(results.scrollTarget(after: Self.results(selected: Self.third)) == .row(Self.second))
  }

  @Test func arrowsUpOntoASectionsFirstRowScrollToItsTitle() {
    let results = Self.results(selected: Self.third, arrowPresses: 1)

    #expect(
      results.scrollTarget(after: Self.results(selected: Self.fourth)) == .sectionTitle(.commands)
    )
  }

  @Test func arrowsUpOntoTheFirstRowScrollToTheTop() {
    let results = Self.results(selected: Self.first, arrowPresses: 1)

    #expect(results.scrollTarget(after: Self.results(selected: Self.second)) == .top)
  }
}
