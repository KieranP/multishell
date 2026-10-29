import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelControlStateClearingTests {
  @Test func eachClearTakesTheDotsItsMenuItemWould() async throws {
    let (harness, session) = Harness.withOnePane()
    let tab = try #require(harness.model.workspace.tab(owning: session.id))
    harness.model.select(harness.feature)
    let requests: [ControlRequest] = [
      .clearPaneState(id: session.id),
      .clearTabState(id: tab.id),
      .clearWorktreeState(id: ControlID.worktree(harness.main.id)),
    ]

    for request in requests {
      harness.messageSource.send(SessionStateReport(state: .done, sessionID: session.id))
      #expect(harness.model.state(ofPane: session.id) == .done)
      #expect(await harness.messageSource.ask(request) == .done)
      #expect(harness.model.state(ofPane: session.id) == nil, "\(request)")
    }
  }

  @Test func aFileTabHasNoDotsToClear() async {
    let harness = Harness()
    let file = harness.openFileTab()

    let reply = await harness.messageSource.ask(.clearTabState(id: file.id))

    #expect(reply == .refused(.tabShowsAFile(id: file.id)))
  }
}
