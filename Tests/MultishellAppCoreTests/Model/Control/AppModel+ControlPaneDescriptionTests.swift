import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlPaneDescriptionTests {
  @Test func aPaneIsDescribedByItsTabWorktreeAndState() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.messageSource.send(
      SessionStateReport(state: .attention, sessionID: tab.focusedSessionID)
    )

    let reply = try #require(
      await harness.messageSource.ask(.describePane(id: tab.focusedSessionID))
    )

    #expect(reply.outputFields["tab"] as? String == tab.id.uuidString)
    #expect(reply.outputFields["worktree"] as? String == ControlID.worktree(harness.main.id))
    #expect(reply.outputFields["isLive"] as? Bool == true)
    #expect(reply.outputFields["isFocused"] as? Bool == true)
    #expect(reply.outputFields["state"] as? String == "attention")
  }

  @Test func aPaneIsShownWithTheWorkersItsAgentHasOut() async throws {
    let harness = Harness()
    let tab = harness.openBackgroundTab()
    let pane = tab.focusedSessionID
    harness.messageSource.send(
      SessionStateReport(
        state: .running,
        sessionID: pane,
        agentID: "claude",
        worker: WorkerReport(id: "w1", phase: .started, type: "Explore"),
      )
    )

    let reply = try #require(await harness.messageSource.ask(.describePane(id: pane)))

    let workers = try #require(reply.outputFields["workers"] as? [[String: Any]])
    #expect(workers.compactMap { $0["id"] as? String } == ["w1"])
    #expect(workers.first?["type"] as? String == "Explore")
  }
}
