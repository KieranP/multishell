import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct PaneRowTests {
  private let paneID = UUID()

  private func row(
    state: SessionState? = nil, select: @escaping () -> Void = {}
  ) -> PaneRow {
    PaneRow(
      pane: SidebarPane(
        id: paneID, title: "zsh",
        position: nil, isFocused: false, state: state, workers: [], agentID: nil,
        agentName: nil),
      theme: .multishellDark, metrics: UIMetrics(fontSize: 13), select: select)
  }

  @Test func aPaneRowRebuiltWithAFreshClosureIsTheSameRow() {
    #expect(row() == row(select: { print("another") }))
  }

  @Test func aPaneRowWhoseStateChangedIsADifferentRow() {
    #expect(row() != row(state: .running))
  }
}
