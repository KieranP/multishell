import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelSidebarRowsTests {
  @Test func thePanesListedAreTheTabsSessionsInOrderWithTheFocusedOneMarked() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.splitActivePane(.horizontal)
    let tab = harness.model.workspace.tabs(in: harness.main.id)[0]

    let panes = harness.model.sidebarPanes(of: harness.main)

    #expect(panes.map(\.id) == tab.sessionIDs)
    #expect(panes.map(\.isFocused) == tab.sessionIDs.map { $0 == tab.focusedSessionID })
    #expect(panes.map(\.position?.number) == [1, 2])
  }

  @Test func aTabListingASessionThatIsGoneGivesItsWorktreeOnlyThePanesItHas() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    var workspace = harness.store.workspace
    let index = try #require(workspace.tabs.firstIndex { $0.worktreeID == harness.main.id })
    let session = workspace.tabs[index].focusedSessionID
    workspace.tabs[index].root = .split(
      axis: .horizontal, children: [.terminal(session), .terminal(UUID())], weights: [1, 1])
    let root = Scratch.path("sidebar-panes")
    defer { Scratch.remove(root) }
    let store = WorkspaceStore(
      workspace: workspace,
      file: StateFile(fileURL: root.appendingPathComponent("state.json")))
    let model = AppModel(store: store, host: FakeEngine(), coordinator: nil, watcher: FakeWatcher())
    model.select(harness.main, openingFirstTab: .never)

    #expect(model.sidebarWorktree(harness.main).panes.map(\.id) == [session])
  }

  @Test func aProjectsRowShowsItsWorktreesStateOnlyWhileTheyAreCollapsed() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.stateSource.send(SessionStateReport(state: .attention, sessionID: tab.focusedSessionID))
    let sessions = harness.model.sessionIDsByWorktree

    #expect(
      harness.model.projectRowState(harness.project.id, isExpanded: false, sessions: sessions)
        == .attention)
    #expect(
      harness.model.projectRowState(harness.project.id, isExpanded: true, sessions: sessions) == nil
    )
  }

  @Test func aWorktreesRowSaysWhetherItIsNamedOrBeingRenamed() {
    let harness = Harness()
    #expect(!harness.model.sidebarWorktree(harness.feature).hasCustomName)

    harness.model.renameWorktree(harness.feature.id, to: "Spike")
    harness.model.beginRenamingWorktree(harness.main)

    #expect(harness.model.sidebarWorktree(harness.feature).customName == "Spike")
    #expect(harness.model.sidebarWorktree(harness.feature).hasCustomName)
    #expect(!harness.model.sidebarWorktree(harness.feature).isRenaming)
    #expect(harness.model.sidebarWorktree(harness.main).isRenaming)
  }

  @Test func onlyTheWorktreeInViewListsItsPanesInTheSidebar() {
    let harness = Harness()
    harness.model.select(harness.feature)
    #expect(harness.model.workspace.tabs(in: harness.feature.id).count == 1)
    harness.model.select(harness.main)
    harness.model.splitActivePane(.horizontal)
    harness.model.newTab()

    #expect(harness.model.sidebarPanes(of: harness.main).count == 3)
    #expect(harness.model.sidebarPanes(of: harness.feature).isEmpty, "its pane is not listed")

    harness.model.showAgentBoard()

    #expect(harness.model.sidebarPanes(of: harness.main).isEmpty)
  }
}
