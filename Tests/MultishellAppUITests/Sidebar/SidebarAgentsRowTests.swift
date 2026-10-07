import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct SidebarAgentsRowTests {
  private let metrics = UIMetrics(fontSize: 13)

  private func row(waiting: Int, select: @escaping () -> Void = {}) -> SidebarAgentsRow {
    SidebarAgentsRow(
      counts: [AgentBoardLaneCount(.waiting, waiting)], isSelected: false, theme: .multishellDark,
      metrics: metrics, select: select)
  }

  @Test func aRowWithAFreshClosureIsTheSameRowUntilItsCountsMove() {
    #expect(row(waiting: 0) == row(waiting: 0, select: { print("another") }))
    #expect(row(waiting: 0) != row(waiting: 1))
  }
}
