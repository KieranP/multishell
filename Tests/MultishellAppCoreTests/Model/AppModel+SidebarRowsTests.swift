import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelSidebarRowsTests {
  @Test func thePanesListedAreTheTabsSessionsInOrderWithTheFocusedOneMarked() {
    let h = Harness()
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let tab = h.model.workspace.tabs(in: h.main.id)[0]

    let panes = h.model.sidebarPanes(of: h.main)

    #expect(panes.map(\.id) == tab.sessionIDs)
    #expect(panes.map(\.isFocused) == tab.sessionIDs.map { $0 == tab.focusedSessionID })
    #expect(panes.map(\.position?.index) == [1, 2])
  }

  @Test func aTabListingASessionThatIsGoneGivesItsWorktreeOnlyThePanesItHas() throws {
    let h = Harness()
    h.model.select(h.main)
    var workspace = h.store.workspace
    let index = try #require(workspace.tabs.firstIndex { $0.worktreeID == h.main.id })
    let session = workspace.tabs[index].focusedSessionID
    workspace.tabs[index].root = .split(
      axis: .horizontal, children: [.terminal(session), .terminal(UUID())], weights: [1, 1])
    let root = Scratch.path("sidebar-panes")
    defer { Scratch.remove(root) }
    let store = WorkspaceStore(
      workspace: workspace,
      file: WorkspaceFile(fileURL: root.appendingPathComponent("state.json")))
    let model = AppModel(store: store, host: FakeEngine(), coordinator: nil, watcher: FakeWatcher())
    model.select(h.main, openingFirstTab: .never)

    #expect(model.sidebarWorktree(h.main).panes.map(\.id) == [session])
  }

  @Test func aWorktreesRowSaysWhetherItIsNamedOrBeingRenamed() {
    let h = Harness()
    #expect(!h.model.sidebarWorktree(h.feature).hasCustomName)

    h.model.renameWorktree(h.feature.id, to: "Spike")
    h.model.beginRenamingWorktree(h.main)

    #expect(h.model.sidebarWorktree(h.feature).customName == "Spike")
    #expect(h.model.sidebarWorktree(h.feature).hasCustomName)
    #expect(!h.model.sidebarWorktree(h.feature).isRenaming)
    #expect(h.model.sidebarWorktree(h.main).isRenaming)
  }
}
