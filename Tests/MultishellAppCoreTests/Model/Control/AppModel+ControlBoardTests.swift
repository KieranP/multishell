import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlBoardTests {
  @Test func theBoardIsListedByColumnWithEachCardByPaneAndWorktreeID() async throws {
    let harness = Harness()
    harness.model.setShowsAllTerminals(true)
    let tab = harness.openBackgroundTab()
    harness.stateSource.send(
      SessionStateReport(state: .attention, sessionID: tab.focusedSessionID)
    )

    let reply = try #require(await harness.stateSource.ask(.listBoard))

    #expect(reply.outputFields["showsAllTerminals"] as? Bool == true)
    let columns = try #require(reply.outputFields["columns"] as? [[String: Any]])
    #expect(columns.compactMap { $0["lane"] as? String } == ["waiting", "working", "done", "idle"])
    let waiting = try #require(columns.first?["cards"] as? [[String: Any]])
    #expect(waiting.compactMap { $0["pane"] as? String } == [tab.focusedSessionID.uuidString])
    #expect(waiting.first?["worktree"] as? String == ControlID.worktree(tab.worktreeID))
    #expect(waiting.first?["project"] as? String == ControlID.project(harness.project.id))
    #expect(waiting.first?["projectName"] as? String == harness.project.name)
    #expect(waiting.first?["state"] as? String == "attention")
  }
}
