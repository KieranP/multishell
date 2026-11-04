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
    state: SessionState? = nil,
    now: Date? = nil,
    select: @escaping () -> Void = {},
  ) -> PaneRow {
    PaneRow(
      pane: SidebarPane(
        id: paneID,
        title: "zsh",
        position: nil,
        isFocused: false,
        state: state,
        since: start,
        workers: [],
        agentID: nil,
        agentName: nil,
      ),
      now: now ?? start,
      theme: .multishellDark,
      metrics: UIMetrics(fontSize: 13, fontFamily: nil),
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
}
