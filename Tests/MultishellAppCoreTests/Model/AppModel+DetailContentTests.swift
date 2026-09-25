import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelDetailContentTests {
  @Test func theDetailAreaAsksTheBoardThenTheOperationThenTheTabs() throws {
    let h = Harness()
    #expect(h.model.detailContent == .noSelection(hasProjects: true))

    h.model.select(h.main, openingFirstTab: .never)
    #expect(h.model.detailContent == .noTabs(h.main))

    h.model.newTab()
    #expect(h.model.detailContent == .tabGroups(h.main))

    h.model.worktreeOperations.begin(.preDeleteHook, on: h.main.id)
    let operation = try #require(h.model.worktreeOperations[h.main.id])
    #expect(h.model.detailContent == .operation(h.main, operation))

    h.model.showAgentBoard()
    #expect(h.model.detailContent == .agentBoard)
  }
}
