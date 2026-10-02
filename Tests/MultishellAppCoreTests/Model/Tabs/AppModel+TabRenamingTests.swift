import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabRenamingTests {
  /// The field commits on losing focus and Escape removes it, so a commit can arrive after
  /// the edit was abandoned. The worktree rename always guarded this; the tab's did not.
  @Test func escapeOnATabsNameFieldIsNotUndoneByTheCommitLosingFocus() {
    let harness = Harness()
    let a = harness.openBackgroundTab()

    harness.model.beginRenamingTab(a.id)
    harness.model.cancelRenamingTab()
    harness.model.commitTabRename(of: a.id, to: "scratch")
    #expect(harness.model.workspace.tab(a.id)?.customTitle == nil, "Escape kept the name it had")
  }

  @Test func aLateBlurFromOneTabsNameFieldLeavesTheNextFieldOpen() throws {
    let harness = Harness()
    let a = harness.openBackgroundTab()
    let b = try #require(harness.model.workspace.activeTab(in: harness.main.id))

    harness.model.beginRenamingTab(a.id)
    harness.model.beginRenamingTab(b.id)
    harness.model.commitTabRename(of: a.id, to: "late")
    #expect(harness.model.workspace.tab(a.id)?.customTitle == nil)
    #expect(harness.model.renamingTabID == b.id, "b is still the one being typed into")

    harness.model.commitTabRename(of: b.id, to: "build")
    #expect(harness.model.workspace.tab(b.id)?.customTitle == "build")
    #expect(harness.model.renamingTabID == nil)
  }

  @Test func useShellTitleWithTheNameFieldOpenIsNotUndoneByTheCommitLosingFocus() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.renameTab(tab.id, to: "build")
    harness.model.beginRenamingTab(tab.id)

    harness.model.renameTab(tab.id, to: nil)
    harness.model.commitTabRename(of: tab.id, to: "build")

    #expect(harness.model.workspace.tab(tab.id)?.customTitle == nil)
    #expect(harness.model.renamingTabID == nil)
  }

  @Test func aRenamedTabIsTitledWithTheNewName() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!

    harness.model.renameTab(tab.id, to: "build")

    #expect(harness.model.workspace.title(of: harness.model.workspace.tab(tab.id)!) == "build")
  }
}
