import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelTabDragTests {
  @Test func aDraggedFileTabLightsNoWorktreeRowAndADropThereRefuses() {
    let harness = Harness()
    let file = harness.openFileTab()

    harness.model.beginTabDrag(file.id)

    #expect(!harness.model.worktreeRowTakesDraggedTab(harness.feature.id))
    #expect(!harness.model.dropDraggedTab(on: .worktree(harness.feature.id)))
    #expect(harness.model.workspace.fileTab(file.id)?.worktreeID == harness.main.id)
  }

  @Test func aDraggedFileTabShufflesPastATerminalTab() throws {
    let harness = Harness()
    let file = harness.openFileTab()
    let shell = try #require(harness.model.workspace.tabs(in: harness.main.id).first)

    harness.model.beginTabDrag(file.id)
    harness.model.shuffleTab(file.id, .before, past: shell.id)

    let group = try #require(harness.model.focusedGroup)
    #expect(
      harness.model.workspace.workspaceTabs(inGroup: group.id).map(\.id) == [file.id, shell.id]
    )
  }
}
