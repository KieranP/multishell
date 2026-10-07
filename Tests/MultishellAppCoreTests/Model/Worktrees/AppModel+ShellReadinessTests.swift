import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelShellReadinessTests {
  /// A worktree selected while it existed could still get new shells after it was deleted by
  /// hand, each landing silently in $HOME.
  @Test func aNewTabOrSplitInAWorktreeWhoseDirectoryVanishedIsRefused() throws {
    let harness = Harness()
    harness.model.select(harness.feature)
    #expect(harness.model.liveTerminalCount == 1)
    try FileManager.default.removeItem(at: harness.feature.path)
    harness.model.presentedError = nil

    harness.model.newTab()
    #expect(harness.model.workspace.tabs(in: harness.feature.id).count == 1)
    #expect(harness.model.presentedError?.title == "Worktree directory is missing")

    harness.model.presentedError = nil
    harness.model.splitActivePane(.horizontal)
    #expect(harness.model.workspace.activeTab(in: harness.feature.id)?.isSplit == false)
    #expect(harness.model.presentedError?.title == "Worktree directory is missing")
    #expect(harness.model.liveTerminalCount == 1, "the shell that already existed is left alone")
  }
}
