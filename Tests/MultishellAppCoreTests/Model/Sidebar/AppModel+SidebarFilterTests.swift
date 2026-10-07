import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelSidebarFilterTests {
  @Test func emptyingTheFilterTextKeepsTheFieldUpAndTheKeyboardInIt() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.sidebarFilterText = "side"
    #expect(harness.model.showsSidebarFilter)
    harness.engine.focused.removeAll()

    harness.model.sidebarFilterText = ""

    let shown = harness.model.showsSidebarFilter
    #expect(shown, "the field has the keyboard and would take it away")
    #expect(harness.engine.focused.isEmpty)
  }

  @Test func closingTheFieldClearsItsTextAndHandsTheKeyboardToTheActivePane() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.setShowsSidebarFilter(true)
    harness.model.sidebarFilterText = "side"
    harness.engine.focused.removeAll()

    harness.model.setShowsSidebarFilter(false)

    #expect(!harness.model.showsSidebarFilter)
    #expect(harness.model.sidebarFilterText.isEmpty)
    #expect(harness.engine.focused == [tab.focusedSessionID])
  }

  @Test func togglingTheFilterOpensTheFieldThenClosesAndClearsIt() {
    let harness = Harness()
    harness.model.select(harness.main)

    harness.model.toggleSidebarFilter()
    #expect(harness.model.showsSidebarFilter)
    harness.model.sidebarFilterText = "side"

    harness.model.toggleSidebarFilter()
    #expect(!harness.model.showsSidebarFilter)
    #expect(harness.model.sidebarFilterText.isEmpty)
  }

  @Test func emptyingTheTextOfAFieldOpenedByHandLeavesItUp() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setShowsSidebarFilter(true)
    harness.model.sidebarFilterText = "side"
    harness.engine.focused.removeAll()

    harness.model.sidebarFilterText = ""

    #expect(harness.model.showsSidebarFilter)
    #expect(harness.engine.focused.isEmpty)
  }

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
