import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelDetailContentTests {
  @Test func theDetailAreaAsksTheBoardThenTheOperationThenTheTabs() throws {
    let harness = Harness()
    #expect(harness.model.detailContent == .noSelection(hasProjects: true))

    harness.model.select(harness.main, openingFirstTab: .never)
    #expect(harness.model.detailContent == .noTabs(harness.main))

    harness.model.newTab()
    #expect(harness.model.detailContent == .tabGroups(harness.main))

    harness.model.worktreeOperations.begin(.preDeleteHook, on: harness.main.id)
    let operation = try #require(harness.model.worktreeOperations[harness.main.id])
    #expect(harness.model.detailContent == .operation(harness.main, operation))

    harness.model.showAgentBoard()
    #expect(harness.model.detailContent == .agentBoard)
  }
}
