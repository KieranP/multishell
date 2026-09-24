import Foundation
import Testing

@testable import MultishellCore

@Suite @MainActor
struct ShellTabTitleTests {
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

  @Test func aProgramsTabKeepsTheProgramsName() throws {
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w"), title: "nvim")

    #expect(session.displayTitle == "nvim")
  }
}
