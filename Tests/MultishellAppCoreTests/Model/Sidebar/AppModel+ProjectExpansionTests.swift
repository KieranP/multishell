import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelProjectExpansionTests {
  @Test func theChevronCollapsesAProjectTheFilterHoldsOpenUntilTheTextChanges() {
    let harness = Harness()
    harness.model.setExpanded(false, for: harness.project)
    harness.model.sidebarFilterText = "feat"
    #expect(harness.model.sidebarEntries.first?.isExpanded == true)

    harness.model.toggleExpansion(of: harness.project)

    #expect(harness.model.sidebarEntries.first?.isExpanded == false)
    #expect(!harness.project.isExpanded, "the stored flag is left for after the filter")
    harness.model.sidebarFilterText = "featu"
    #expect(harness.model.sidebarEntries.first?.isExpanded == true)
  }

  @Test func withNoFilterTheChevronSetsTheStoredFlag() {
    let harness = Harness()
    harness.model.setExpanded(true, for: harness.project)

    harness.model.toggleExpansion(of: harness.project)

    #expect(!harness.project.isExpanded)
    #expect(harness.model.sidebarEntries.first?.isExpanded == false)
  }

  @Test func renamingARowOfAProjectCollapsedUnderTheFilterExpandsIt() {
    let harness = Harness()
    harness.model.sidebarFilterText = "feat"
    harness.model.toggleExpansion(of: harness.project)

    harness.model.beginRenamingWorktree(harness.feature)

    #expect(harness.model.sidebarEntries.first?.isExpanded == true)
  }

  @Test func removingAProjectDropsItsCollapseWhileFiltering() {
    let harness = Harness()
    harness.model.sidebarFilterText = "feat"
    harness.model.toggleExpansion(of: harness.project)

    harness.model.removeProject(harness.project)

    #expect(harness.model.projectsCollapsedWhileFiltering.isEmpty)
  }

  @Test func renamingARowTheFilterShowsLeavesTheStoredFlagAlone() {
    let harness = Harness()
    harness.model.setExpanded(false, for: harness.project)
    harness.model.sidebarFilterText = "feat"

    harness.model.beginRenamingWorktree(harness.feature)

    #expect(!harness.project.isExpanded)
    #expect(harness.model.sidebarEntries.first?.isExpanded == true)
  }
}
