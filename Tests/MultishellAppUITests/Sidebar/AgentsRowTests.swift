import MultishellAppCore
import MultishellCore
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct AgentsRowTests {
  private let metrics = UIMetrics(fontSize: 13)

  @Test func theAgentsRowComparesItsCounts() {
    let none = AgentsRow(
      counts: [(.waiting, 0)], isSelected: false, theme: .multishellDark, metrics: metrics,
      select: {})
    let one = AgentsRow(
      counts: [(.waiting, 1)], isSelected: false, theme: .multishellDark, metrics: metrics,
      select: {})
    #expect(none == none)
    #expect(none != one)
  }
}
