import MultishellAppCore
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct AgentBoardRowTests {
  private let metrics = UIMetrics(fontSize: 13)

  @Test func theBoardRowComparesItsCounts() {
    let none = AgentBoardRow(
      counts: [(.waiting, 0)], isSelected: false, theme: .multishellDark, metrics: metrics,
      select: {})
    let one = AgentBoardRow(
      counts: [(.waiting, 1)], isSelected: false, theme: .multishellDark, metrics: metrics,
      select: {})
    #expect(none == none)
    #expect(none != one)
  }
}
