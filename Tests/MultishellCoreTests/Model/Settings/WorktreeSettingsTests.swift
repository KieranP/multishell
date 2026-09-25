import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct WorktreeSettingsTests {
  private let project = Project(path: URL(fileURLWithPath: "/Users/dev/Work/multishell"))

  @Test func theDefaultContainerIsASiblingNamedAfterTheProject() {
    #expect(
      WorktreeSettings().worktreeContainer(for: project).path
        == "/Users/dev/Work/multishell-worktrees")
  }

  @Test func anAbsoluteContainerIgnoresTheRepositoryPath() {
    let settings = WorktreeSettings(worktreeDirectory: "/tmp/trees")
    #expect(settings.worktreeContainer(for: project).path == "/tmp/trees")
  }

  @Test func aRelativeContainerResolvesAgainstTheRepository() {
    let settings = WorktreeSettings(worktreeDirectory: ".worktrees")
    #expect(
      settings.worktreeContainer(for: project).path == "/Users/dev/Work/multishell/.worktrees")
  }

  @Test func resolutionDoesNotDependOnTheDirectoryExisting() {
    // The fixture path does not exist on any machine; the answer must not
    // change between a machine where it does and one where it does not.
    let ghost = Project(path: URL(fileURLWithPath: "/nowhere/at/all/repo"))
    let settings = WorktreeSettings(worktreeDirectory: ".worktrees")
    #expect(settings.worktreeContainer(for: ghost).path == "/nowhere/at/all/repo/.worktrees")
    #expect(
      WorktreeSettings().worktreeContainer(for: ghost).path == "/nowhere/at/all/repo-worktrees")
  }

  @Test func aBlankContainerMeansTheDefaultNotTheRepository() {
    // An override cleared to nothing, or the global field emptied, would
    // otherwise put worktrees inside the main checkout as untracked files.
    for text in ["", " ", "\t"] {
      let settings = WorktreeSettings(worktreeDirectory: text)
      #expect(
        settings.worktreeContainer(for: project).path == "/Users/dev/Work/multishell-worktrees",
        "\(text.debugDescription)")
    }
    let overridden = ProjectSettings(worktreeDirectory: " ").effective(
      defaults: WorktreeSettings(worktreeDirectory: "/global/trees"))
    #expect(
      overridden.worktreeContainer(for: project).path == "/Users/dev/Work/multishell-worktrees")
  }

  @Test func slashesInBranchNamesBecomeOneDirectory() {
    let path = WorktreeSettings().worktreePath(forBranch: "feat/tabs", in: project)
    #expect(path.path == "/Users/dev/Work/multishell-worktrees/feat-tabs")
  }

  @Test func noBranchNameCanPutAWorktreeOutsideTheContainer() {
    // git rejects most of these as branch names, but the path is computed
    // and shown, and its parent created, before git is asked.
    let container = WorktreeSettings().worktreeContainer(for: project).path
    for name in ["..", ".", "", " ", "../..", "/", "//", "a/../../b", "...", "./x", "-"] {
      let path = WorktreeSettings().worktreePath(forBranch: name, in: project).standardizedFileURL
        .path
      #expect(path.hasPrefix(container + "/"), "\(name) -> \(path)")
      #expect(path.count > container.count + 1, "\(name) must name something")
    }
  }

  @Test func theBranchPrefixIsAppliedOnce() {
    let settings = WorktreeSettings(branchPrefix: "kieran/")
    #expect(settings.qualifiedBranch("tabs") == "kieran/tabs")
    #expect(settings.qualifiedBranch("kieran/tabs") == "kieran/tabs")
  }

  @Test func anEmptyPrefixLeavesTheNameAlone() {
    #expect(WorktreeSettings().qualifiedBranch(" tabs ") == "tabs")
  }
}
