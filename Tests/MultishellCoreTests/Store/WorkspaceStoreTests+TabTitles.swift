import Foundation
import Observation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func aCustomTitleWinsOverTheStartingTitleUntilCleared() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    #expect(store.workspace.title(of: store.workspace.tab(tab.id)!) == "Shell")

    store.setCustomTitle("  build  ", forTab: tab.id)
    #expect(store.workspace.title(of: store.workspace.tab(tab.id)!) == "build")

    store.setCustomTitle("", forTab: tab.id)
    #expect(store.workspace.tab(tab.id)?.customTitle == nil)
    #expect(store.workspace.title(of: store.workspace.tab(tab.id)!) == "Shell")
  }

  @Test func aCommandTabStartsWithTheCommandsName() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id, command: ["/usr/bin/top", "-o", "cpu"])!
    #expect(store.workspace.title(of: tab) == "top")
  }

  @Test func aPlainShellsTitleIsSavedAsNoneAndReadInTheCurrentLanguage() throws {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)

    let tab = try #require(store.openTab(in: worktree.id))
    let session = try #require(store.workspace.session(tab.focusedSessionID))

    #expect(session.title.isEmpty)
    #expect(session.displayTitle == t("tab.shell"))
    #expect(store.workspace.title(of: tab) == t("tab.shell"))
  }
}
