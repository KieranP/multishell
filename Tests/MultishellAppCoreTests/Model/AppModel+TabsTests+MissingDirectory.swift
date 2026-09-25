import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelTabsTests {
  /// A worktree selected while it existed could still get new shells after it was deleted by
  /// hand, each landing silently in $HOME.
  @Test func aNewTabOrSplitInAWorktreeWhoseDirectoryVanishedIsRefused() throws {
    let h = Harness()
    h.model.select(h.feature)
    #expect(h.model.liveTerminalCount == 1)
    try FileManager.default.removeItem(at: h.feature.path)
    h.model.presentedError = nil

    h.model.newTab()
    #expect(h.model.workspace.tabs(in: h.feature.id).count == 1)
    #expect(h.model.presentedError?.title == "Worktree directory is missing")

    h.model.presentedError = nil
    h.model.splitActivePane(.horizontal)
    #expect(h.model.workspace.activeTab(in: h.feature.id)?.isSplit == false)
    #expect(h.model.presentedError?.title == "Worktree directory is missing")
    #expect(h.model.liveTerminalCount == 1, "the shell that already existed is left alone")
  }
}
