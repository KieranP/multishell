import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelSidebarFilterTests {
  @Test func textLeftFromAnEarlierWindowKeepsTheFieldUpOnceItIsEmptied() {
    let h = Harness()
    h.model.select(h.main)
    h.model.sidebarFilterText = "side"
    #expect(h.model.showsSidebarFilter)
    h.engine.focused.removeAll()

    h.model.sidebarFilterText = ""

    let shown = h.model.showsSidebarFilter
    #expect(shown, "the field has the keyboard and would take it away")
    #expect(h.engine.focused.isEmpty)
  }

  @Test func closingTheFieldClearsItsTextAndHandsTheKeyboardToTheActivePane() throws {
    let h = Harness()
    h.model.select(h.main)
    let tab = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.setShowsSidebarFilter(true)
    h.model.sidebarFilterText = "side"
    h.engine.focused.removeAll()

    h.model.setShowsSidebarFilter(false)

    #expect(!h.model.showsSidebarFilter)
    #expect(h.model.sidebarFilterText.isEmpty)
    #expect(h.engine.focused == [tab.focusedSessionID])
  }

  @Test func emptyingTheTextOfAFieldOpenedByHandLeavesItUp() {
    let h = Harness()
    h.model.select(h.main)
    h.model.setShowsSidebarFilter(true)
    h.model.sidebarFilterText = "side"
    h.engine.focused.removeAll()

    h.model.sidebarFilterText = ""

    #expect(h.model.showsSidebarFilter)
    #expect(h.engine.focused.isEmpty)
  }

  @Test func theChevronFoldsAProjectTheFilterHoldsOpenUntilTheTextChanges() {
    let h = Harness()
    h.model.setExpanded(false, for: h.project)
    h.model.sidebarFilterText = "feat"
    #expect(h.model.sidebarEntries.first?.isExpanded == true)

    h.model.toggleExpansion(of: h.project)

    #expect(h.model.sidebarEntries.first?.isExpanded == false)
    #expect(!h.project.isExpanded, "the stored flag is left for after the filter")
    h.model.sidebarFilterText = "featu"
    #expect(h.model.sidebarEntries.first?.isExpanded == true)
  }

  @Test func withNoFilterTheChevronSetsTheStoredFlag() {
    let h = Harness()
    h.model.setExpanded(true, for: h.project)

    h.model.toggleExpansion(of: h.project)

    #expect(!h.project.isExpanded)
    #expect(h.model.sidebarEntries.first?.isExpanded == false)
  }

  @Test func renamingARowOfAProjectFoldedUnderTheFilterUnfoldsIt() {
    let h = Harness()
    h.model.sidebarFilterText = "feat"
    h.model.toggleExpansion(of: h.project)

    h.model.beginRenamingWorktree(h.feature)

    #expect(h.model.sidebarEntries.first?.isExpanded == true)
  }

  @Test func removingAProjectDropsItsFoldWhileFiltering() {
    let h = Harness()
    h.model.sidebarFilterText = "feat"
    h.model.toggleExpansion(of: h.project)

    h.model.removeProject(h.project)

    #expect(h.model.projectsFoldedWhileFiltering.isEmpty)
  }

  @Test func renamingARowTheFilterShowsLeavesTheStoredFlagAlone() {
    let h = Harness()
    h.model.setExpanded(false, for: h.project)
    h.model.sidebarFilterText = "feat"

    h.model.beginRenamingWorktree(h.feature)

    #expect(!h.project.isExpanded)
    #expect(h.model.sidebarEntries.first?.isExpanded == true)
  }
}
