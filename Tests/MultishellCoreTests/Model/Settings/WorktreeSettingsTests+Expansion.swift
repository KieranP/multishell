import Foundation
import Testing

@testable import MultishellCore

extension WorktreeSettingsTests {
  @Test func tildeExpandsToTheHomeDirectory() {
    let project = Project(path: URL(fileURLWithPath: "/w/repo"))
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    #expect(
      WorktreeSettings(worktreeDirectory: "~/trees").worktreeContainer(for: project).path
        == "\(home)/trees")
    #expect(WorktreeSettings(worktreeDirectory: "~").worktreeContainer(for: project).path == home)
  }

  @Test func projectPlaceholderWorksInAbsolutePaths() {
    let project = Project(path: URL(fileURLWithPath: "/w/repo"))
    let settings = WorktreeSettings(worktreeDirectory: "/srv/trees/{project}")
    #expect(settings.worktreeContainer(for: project).path == "/srv/trees/repo")
  }

  @Test func aTildeInTheMiddleIsNotExpanded() {
    let project = Project(path: URL(fileURLWithPath: "/w/repo"))
    let settings = WorktreeSettings(worktreeDirectory: "odd~name")
    #expect(settings.worktreeContainer(for: project).path == "/w/repo/odd~name")
  }
}
