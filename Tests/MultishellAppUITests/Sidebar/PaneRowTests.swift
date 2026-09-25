import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct PaneRowTests {
  private func row(
    state: SessionState? = nil, select: @escaping () -> Void = {}
  ) -> PaneRow {
    PaneRow(
      title: "zsh", position: nil, isFocusedPane: false, state: state, subagents: [],
      agentID: nil, agentName: nil, theme: .multishellDark, metrics: UIMetrics(fontSize: 13),
      select: select)
  }

  @Test func aPaneRowRebuiltWithAFreshClosureIsTheSameRow() {
    #expect(row() == row(select: { print("another") }))
  }

  @Test func aPaneRowWhoseStateChangedIsNot() {
    #expect(row() != row(state: .running))
  }
}
