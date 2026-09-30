import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct SidebarAgentsRowTests {
  private let metrics = UIMetrics(fontSize: 13)

  @Test func theBoardRowComparesItsCounts() {
    let none = SidebarAgentsRow(
      counts: [AgentLaneCount(.waiting, 0)], isSelected: false, theme: .multishellDark,
      metrics: metrics,
      select: {})
    let one = SidebarAgentsRow(
      counts: [AgentLaneCount(.waiting, 1)], isSelected: false, theme: .multishellDark,
      metrics: metrics,
      select: {})
    #expect(none == none)
    #expect(none != one)
  }
}
