import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabRenamingTests {
  /// The field commits on losing focus and Escape removes it, so a commit can arrive after
  /// the edit was abandoned. The worktree rename always guarded this; the tab's did not.
  @Test func escapeOnATabsNameFieldIsNotUndoneByTheCommitLosingFocus() throws {
    let h = Harness()
    h.model.select(h.main)
    let a = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.newTab()
    let b = try #require(h.model.workspace.activeTab(in: h.main.id))

    h.model.beginRenamingTab(a.id)
    h.model.cancelRenamingTab()
    h.model.commitTabRename(of: a.id, to: "scratch")
    #expect(h.model.workspace.tab(a.id)?.customTitle == nil, "Escape kept the name it had")

    // A second field opening must not be closed by the first one's late blur.
    h.model.beginRenamingTab(a.id)
    h.model.beginRenamingTab(b.id)
    h.model.commitTabRename(of: a.id, to: "late")
    #expect(h.model.workspace.tab(a.id)?.customTitle == nil)
    #expect(h.model.renamingTabID == b.id, "b is still the one being typed into")

    h.model.commitTabRename(of: b.id, to: "build")
    #expect(h.model.workspace.tab(b.id)?.customTitle == "build")
    #expect(h.model.renamingTabID == nil)
  }

  @Test func useShellTitleWithTheNameFieldOpenIsNotUndoneByTheCommitLosingFocus() throws {
    let h = Harness()
    h.model.select(h.main)
    let tab = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.renameTab(tab.id, to: "build")
    h.model.beginRenamingTab(tab.id)

    h.model.renameTab(tab.id, to: nil)
    h.model.commitTabRename(of: tab.id, to: "build")

    #expect(h.model.workspace.tab(tab.id)?.customTitle == nil)
    #expect(h.model.renamingTabID == nil)
  }

  @Test func tabRenamesAndReordersReachTheStore() {
    let h = Harness()
    h.model.select(h.main)
    let a = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let b = h.model.workspace.activeTab(in: h.main.id)!

    h.model.renameTab(a.id, to: "build")
    h.model.moveTab(b.id, .before, anchor: a.id)

    #expect(h.model.workspace.title(of: h.model.workspace.tab(a.id)!) == "build")
    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [b.id, a.id])

    h.model.moveTab(b.id, .after, anchor: a.id)
    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [a.id, b.id])
  }
}
