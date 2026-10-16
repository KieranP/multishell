import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelPaneSplitsTests {
  @Test func aSplitAskedOfAFileTabSplitsNothing() throws {
    let harness = Harness()
    let file = harness.openFileTab()
    let group = try #require(harness.model.focusedGroup)
    let sessions = harness.model.workspace.sessions

    harness.model.splitActivePane(.horizontal)
    harness.model.splitActivePane(.vertical, in: group.id)

    #expect(harness.model.workspace.sessions == sessions)
    #expect(harness.model.workspace.activeWorkspaceTab(in: harness.main.id)?.id == file.id)
  }

  @Test func aGroupShowingAFileOffersNoSplitAndOneShowingATerminalDoes() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let group = try #require(harness.model.focusedGroup)
    #expect(harness.model.canSplitShownTab(in: group.id))

    _ = harness.openFileTab()

    #expect(!harness.model.canSplitShownTab(in: group.id))
  }
}
