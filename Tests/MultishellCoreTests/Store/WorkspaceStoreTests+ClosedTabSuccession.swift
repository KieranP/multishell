import Testing

@testable import MultishellCore

/// Which tab a group shows once the one it was showing leaves. A strip hands
/// the place to whatever slid into it; see Docs/design/tabs-and-groups.md.
extension WorkspaceStoreTests {
  private func group(of worktree: Worktree.ID, in store: WorkspaceStore) -> TabGroup {
    store.workspace.groups(in: worktree)[0]
  }

  @Test func closingTheShownTabShowsItsNeighbourRatherThanTheLastTab() {
    let (store, _, worktree) = demoStore()
    let tabs = (0..<4).map { _ in store.openTab(in: worktree.id)! }
    store.activateTab(tabs[1].id)

    store.closeTab(tabs[1].id)

    #expect(
      group(of: worktree.id, in: store).activeTabID == tabs[2].id,
      "the tab that slid into the closed one's place, not the rightmost")
    WorkspaceInvariants.check(store.workspace, "closed middle tab")
  }

  @Test func closingTheLastTabOfAStripFallsBackToTheOneBeforeIt() {
    let (store, _, worktree) = demoStore()
    let tabs = (0..<3).map { _ in store.openTab(in: worktree.id)! }
    store.activateTab(tabs[2].id)

    store.closeTab(tabs[2].id)

    #expect(group(of: worktree.id, in: store).activeTabID == tabs[1].id)
  }

  @Test func draggingTheShownTabAwayLeavesItsNeighbourShowing() {
    let (store, _, worktree) = demoStore()
    let tabs = (0..<4).map { _ in store.openTab(in: worktree.id)! }
    let first = group(of: worktree.id, in: store)
    store.activateTab(tabs[1].id)

    store.moveTabToNewGroup(tabs[1].id, .after, of: first.id)

    #expect(store.workspace.group(first.id)?.activeTabID == tabs[2].id)
    WorkspaceInvariants.check(store.workspace, "dragged shown tab out")
  }

  @Test func droppingTheShownTabOnAnotherGroupLeavesItsNeighbourShowing() {
    let (store, _, worktree) = demoStore()
    let tabs = (0..<4).map { _ in store.openTab(in: worktree.id)! }
    let first = group(of: worktree.id, in: store)
    let made = store.moveTabToNewGroup(tabs[3].id, .after, of: first.id)!
    store.activateTab(tabs[1].id)

    store.moveTab(tabs[1].id, .before, tabs[3].id)

    #expect(store.workspace.group(first.id)?.activeTabID == tabs[2].id)
    #expect(store.workspace.tabs(in: made.id).map(\.id) == [tabs[1].id, tabs[3].id])
    WorkspaceInvariants.check(store.workspace, "moved shown tab across groups")
  }

  @Test func closingATabNobodyWasLookingAtLeavesTheShownOneAlone() {
    let (store, _, worktree) = demoStore()
    let tabs = (0..<3).map { _ in store.openTab(in: worktree.id)! }
    store.activateTab(tabs[2].id)

    store.closeTab(tabs[0].id)

    #expect(group(of: worktree.id, in: store).activeTabID == tabs[2].id)
  }
}
