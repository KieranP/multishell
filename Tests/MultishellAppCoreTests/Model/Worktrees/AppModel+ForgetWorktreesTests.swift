import MultishellCore
import MultishellGitKit
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelForgetWorktreesTests {
  @Test func aForgottenWorktreeLeavesNoFilesPanelStateForOneMadeAtItsPath() {
    let harness = Harness()
    let id = harness.main.id
    harness.model.trackedFiles[id] = .empty
    harness.model.ignoredEntries[id] = ["node_modules/"]
    harness.model.ignoredEntriesReads.start(id) { Task {} }
    harness.model.ignoredEntriesReads.start(id) { Task {} }
    harness.model.setFilesPanelFilterText("src", in: id)

    harness.model.forgetWorktrees([id])

    #expect(harness.model.trackedFiles[id] == nil)
    #expect(harness.model.ignoredEntries[id] == nil)
    #expect(!harness.model.ignoredEntriesReads.isRunning(id))
    harness.model.ignoredEntriesReads.start(id) { Task {} }
    let isAskedAgain = harness.model.ignoredEntriesReads.finish(id)
    #expect(!isAskedAgain)
    #expect(harness.model.filesPanelState(of: id).filterText.isEmpty)
  }
}
