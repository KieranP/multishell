import Foundation
import MultishellCore
import MultishellGitKit
import TestScratch
import Testing

@testable import MultishellAppCore

extension AppModelPersistenceTests {
  @Test func aSavedWorkspaceComesBackAndWarmsOnTheFirstVisit() throws {
    let file = Scratch.path("relaunch")
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    let before = Harness(stateFile: file)
    before.model.select(before.main)
    before.model.splitActivePane(.horizontal)
    let splitTab = before.model.workspace.activeTab(in: before.main.id)!
    before.model.setSplitWeights([3, 1], at: [], ofTab: splitTab.id)
    before.model.newTab()
    before.model.renameTab(before.model.workspace.activeTab(in: before.main.id)!.id, to: "build")
    before.model.select(before.feature)
    before.model.newTab()
    #expect(before.model.liveTerminalCount == 5, "two in the split, one more, then two in feature")
    before.model.saveNow()
    var expected = before.model.workspace
    expected.selectedWorktreeID = nil

    let (store, error) = WorkspaceStore.restored(from: WorkspaceFile(fileURL: file))
    #expect(error == nil)
    let engine = FakeEngine()
    let after = AppModel(
      store: store, host: engine,
      coordinator: nil, watcher: FakeWatcher())

    #expect(after.workspace == expected, "everything but the selection, which a launch clears")
    #expect(after.liveTerminalCount == 0, "nothing starts until a worktree is visited")

    after.select(before.main)
    #expect(after.liveTerminalCount == 3, "both tabs of main, one of them split")
    let tabs = after.workspace.tabs(in: before.main.id)
    #expect(tabs.map(\.isSplit) == [true, false])
    #expect(after.title(of: tabs[1]) == "build")
    guard case .split(.horizontal, _, let weights) = tabs[0].root else {
      Issue.record("the split did not come back")
      return
    }
    #expect(weights == [3, 1])
    #expect(after.workspace.activeTab(in: before.main.id)?.id == tabs[1].id)
    #expect(engine.openSessionIDs == Set(after.workspace.sessions(in: before.main.id).map(\.id)))

    after.select(before.feature)
    #expect(after.liveTerminalCount == 5)
  }
}
