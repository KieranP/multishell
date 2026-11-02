import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelWorktreeHidingTests {
  @Test func hidingAWorktreeMovesItsRowIntoTheCollapsedHiddenSection() {
    let harness = Harness()

    harness.model.setHidden(true, worktree: harness.feature)

    #expect(harness.model.isHidden(harness.feature))
    let entry = harness.model.sidebarEntries[0]
    #expect(entry.worktrees.map(\.id) == [harness.main.id])
    #expect(entry.hiddenWorktrees.map(\.id) == [harness.feature.id])
    #expect(!harness.model.sidebarRowIDs().contains(harness.feature.id))
  }

  @Test func expandingTheHiddenSectionPutsItsRowsOnTheSidebar() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)

    harness.model.toggleHiddenSectionExpansion(of: harness.project)

    #expect(harness.model.sidebarEntries[0].isHiddenSectionExpanded)
    #expect(harness.model.sidebarRowIDs().contains(harness.feature.id))

    harness.model.toggleHiddenSectionExpansion(of: harness.project)
    #expect(!harness.model.sidebarRowIDs().contains(harness.feature.id))
  }

  @Test func showingAHiddenWorktreePutsItBackWithTheRest() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)

    harness.model.setHidden(false, worktree: harness.feature)

    #expect(!harness.model.isHidden(harness.feature))
    #expect(harness.model.sidebarEntries[0].worktrees.count == 2)
    #expect(harness.model.sidebarEntries[0].hiddenWorktrees.isEmpty)
  }

  @Test func renamingAHiddenWorktreeExpandsItsSection() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)

    harness.model.beginRenamingWorktree(harness.feature)

    #expect(harness.model.sidebarEntries[0].isHiddenSectionExpanded)
  }

  @Test func hidingTheWorktreeBeingRenamedEndsTheRename() {
    let harness = Harness()
    harness.model.beginRenamingWorktree(harness.feature)

    harness.model.setHidden(true, worktree: harness.feature)

    #expect(harness.model.renamingWorktreeID == nil)
  }

  @Test func removingAProjectForgetsItsHiddenSectionWasExpanded() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)
    harness.model.toggleHiddenSectionExpansion(of: harness.project)

    harness.model.removeProject(harness.project)

    #expect(harness.model.expandedHiddenSections.isEmpty)
  }

  @Test func renamingAHiddenWorktreeTheFilterFindsKeepsTheFilter() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)
    harness.model.sidebarFilterText = "feat"

    harness.model.beginRenamingWorktree(harness.feature)

    #expect(harness.model.sidebarFilterText == "feat")
    #expect(harness.model.sidebarEntries[0].isHiddenSectionExpanded)
    #expect(harness.model.sidebarRowIDs().contains(harness.feature.id))
  }

  @Test func renamingAHiddenWorktreeTheFilterMissesClearsTheFilterAndExpandsItsSection() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)
    harness.model.sidebarFilterText = "matches-no-row"

    harness.model.beginRenamingWorktree(harness.feature)

    #expect(harness.model.sidebarFilterText.isEmpty)
    #expect(harness.model.sidebarRowIDs().contains(harness.feature.id))
  }

  @Test func renamingAHiddenWorktreeOfACollapsedProjectExpandsBoth() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)
    harness.model.setExpanded(false, for: harness.project)

    harness.model.beginRenamingWorktree(harness.feature)

    #expect(harness.project.isExpanded)
    #expect(harness.model.sidebarRowIDs().contains(harness.feature.id))
  }

  @Test func choosingAHiddenWorktreeInTheQuickSwitcherExpandsItsSection() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)
    harness.model.toggleQuickSwitcher(.worktrees)

    harness.model.chooseQuickSwitcherRow(.worktree(harness.feature.id))

    #expect(harness.model.sidebarRowIDs().contains(harness.feature.id))
  }

  @Test func hidingTheSelectedWorktreeKeepsItSelected() {
    let harness = Harness()
    harness.model.select(harness.feature)

    harness.model.setHidden(true, worktree: harness.feature)

    #expect(harness.model.workspace.selectedWorktreeID == harness.feature.id)
  }

  @Test func aSelectedHiddenWorktreeIsStillReadWithItsSectionCollapsed() {
    let harness = Harness()
    harness.model.select(harness.feature)
    harness.model.setHidden(true, worktree: harness.feature)

    #expect(!harness.model.sidebarRowIDs().contains(harness.feature.id))
    #expect(harness.model.polledRowIDs().contains(harness.feature.id), "the selected row is read")
  }

  @Test func hidingTheMainWorktreeDoesNothing() {
    let harness = Harness()

    harness.model.setHidden(true, worktree: harness.main)

    #expect(!harness.model.isHidden(harness.main))
    #expect(harness.model.sidebarEntries[0].worktrees.map(\.id).contains(harness.main.id))
  }

  @Test func aHiddenWorktreeRemovedFromDiskComesBackShownIfMadeAgainAtThatPath() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)

    harness.store.replaceWorktrees([harness.main], forProject: harness.project.id)
    harness.store.replaceWorktrees(
      [harness.main, harness.feature],
      forProject: harness.project.id,
    )

    #expect(!harness.model.isHidden(harness.feature))
  }

  @Test func hiddenMarksSurviveASaveAndReload() throws {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)

    let data = try JSONEncoder().encode(harness.model.workspace)
    var reloaded = try JSONDecoder().decode(Workspace.self, from: data)
    reloaded.repair()

    #expect(reloaded.isHidden(harness.feature))
  }

  @Test func anExpandedHiddenSectionOfACollapsedProjectPutsNoRowOnTheSidebar() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)
    harness.model.toggleHiddenSectionExpansion(of: harness.project)

    harness.model.setExpanded(false, for: harness.project)

    #expect(!harness.model.sidebarRowIDs().contains(harness.feature.id))
  }

  @Test func hidingAWorktreeThatHasGoneChangesNothing() {
    let harness = Harness()
    harness.store.replaceWorktrees([harness.main], forProject: harness.project.id)

    harness.model.setHidden(true, worktree: harness.feature)

    #expect(harness.model.workspace.hiddenWorktreeIDs.isEmpty)
  }

  @Test func aHiddenWorktreeKeepsItsCustomName() {
    let harness = Harness()
    harness.model.renameWorktree(harness.feature.id, to: "Checkout flow")

    harness.model.setHidden(true, worktree: harness.feature)
    harness.model.setHidden(false, worktree: harness.feature)

    #expect(harness.model.customName(of: harness.feature) == "Checkout flow")
  }

  @Test func theFilterFindsAHiddenWorktreeByItsCustomName() {
    let harness = Harness()
    harness.model.renameWorktree(harness.feature.id, to: "Checkout flow")
    harness.model.setHidden(true, worktree: harness.feature)

    harness.model.sidebarFilterText = "checkout"

    #expect(harness.model.sidebarEntries.first?.hiddenWorktrees.map(\.id) == [harness.feature.id])
  }
}
