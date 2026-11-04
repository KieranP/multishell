import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelHiddenSectionExpansionTests {
  @Test func expandingTheHiddenSectionPutsItsRowsOnTheSidebar() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)

    harness.model.toggleHiddenSectionExpansion(of: harness.project)

    #expect(harness.model.sidebarEntries[0].isHiddenSectionExpanded)
    #expect(harness.model.sidebarRowIDs().contains(harness.feature.id))

    harness.model.toggleHiddenSectionExpansion(of: harness.project)
    #expect(!harness.model.sidebarRowIDs().contains(harness.feature.id))
  }

  @Test func removingAProjectForgetsItsHiddenSectionWasExpanded() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)
    harness.model.toggleHiddenSectionExpansion(of: harness.project)

    harness.model.removeProject(harness.project)

    #expect(harness.model.expandedHiddenSections.isEmpty)
  }

  @Test func anExpandedHiddenSectionOfACollapsedProjectPutsNoRowOnTheSidebar() {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)
    harness.model.toggleHiddenSectionExpansion(of: harness.project)

    harness.model.setExpanded(false, for: harness.project)

    #expect(!harness.model.sidebarRowIDs().contains(harness.feature.id))
  }
}
