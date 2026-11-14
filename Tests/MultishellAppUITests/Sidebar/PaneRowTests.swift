import AppKit
import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct PaneRowTests {
  private let paneID = UUID()
  private let start = Date(timeIntervalSince1970: 1_000_000)

  private func row(
    title: String = "zsh",
    state: SessionState? = nil,
    now: Date? = nil,
    isFocused: Bool = false,
    theme: Theme = .multishellDark,
    metrics: UIMetrics = UIMetrics(fontSize: 13, fontFamily: nil),
    select: @escaping () -> Void = {},
  ) -> PaneRow {
    PaneRow(
      pane: SidebarPane(
        id: paneID,
        title: title,
        position: nil,
        isFocused: isFocused,
        state: state,
        since: start,
        workers: [],
        agentID: nil,
        agentName: nil,
      ),
      now: now ?? start,
      theme: theme,
      metrics: metrics,
      select: select,
    )
  }

  @Test func aPaneRowRebuiltWithAFreshClosureIsTheSameRow() {
    #expect(row() == row(select: { print("another") }))
  }

  @Test func aPaneRowWhoseStateChangedIsADifferentRow() {
    #expect(row() != row(state: .running))
  }

  @Test func aWorkingPaneRowWhoseClockTickedIsADifferentRow() {
    #expect(row(state: .running) != row(state: .running, now: start.addingTimeInterval(10)))
  }

  @Test func anIdlePaneRowIsTheSameRowAfterATick() {
    #expect(row(state: .idle) == row(state: .idle, now: start.addingTimeInterval(10)))
  }

  @Test func inTheLargestFontAtTheSidebarsNarrowestTheTitleKeepsThreeCharacters() throws {
    let theme = try MagentaTheme.with([.projectsPanel: [.text]])
    let metrics = UIMetrics(fontSize: Appearance.uiFontSizes.upperBound, fontFamily: nil)
    let rowWidth = SidebarWidth.minimum - 2 * UIMetrics.sidebarListSideInset
    func inkedSpan(of row: PaneRow, width: Double) throws -> Int {
      let bitmap = try #require(
        OffscreenWindow.pixels(
          ofHosted: row,
          size: CGSize(width: width, height: metrics.paneRowHeight),
        )
      )
      let columns = MagentaTheme.inkedColumns(in: bitmap)
      return (columns.last ?? 0) - (columns.first ?? 0)
    }
    let threeCharacters = row(title: "abc", isFocused: true, theme: theme, metrics: metrics)
    let working = row(
      title: "Refactoring",
      state: .running,
      now: start.addingTimeInterval(19),
      isFocused: true,
      theme: theme,
      metrics: metrics,
    )

    let reference = try inkedSpan(of: threeCharacters, width: 400)
    let crowded = try inkedSpan(of: working, width: rowWidth)

    #expect(reference > 0)
    #expect(crowded >= reference)
  }
}
