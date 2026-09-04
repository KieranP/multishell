import Foundation
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

@Suite
struct ProjectSettingsTests {
  private let defaults = WorktreeSettings(worktreeDirectory: "/global/trees", branchPrefix: "team/")

  @Test func nilFieldsFallBackToTheGlobalDefaults() {
    let effective = ProjectSettings().effective(defaults: defaults)
    #expect(effective == defaults)
  }

  @Test func eachFieldOverridesIndependently() {
    let effective = ProjectSettings(branchPrefix: "kieran/").effective(defaults: defaults)
    #expect(effective.worktreeDirectory == "/global/trees")
    #expect(effective.branchPrefix == "kieran/")
  }

  @Test func aWhitespaceOverrideMeansNone() {
    // The sheet stores a lone space to opt a project out of a global
    // prefix; it must not end up in the branch name.
    let effective = ProjectSettings(branchPrefix: " ").effective(defaults: defaults)
    #expect(effective.branchPrefix == "")
    #expect(effective.qualifiedBranch("tabs") == "tabs")
  }

  @Test func legacyEmptyStringsDecodeAsNoOverride() throws {
    let json = Data(
      #"{ "worktreeDirectory": "./.worktrees", "branchPrefix": "", "postCreateHook": "", "postDeleteHook": "" }"#
        .utf8)
    let settings = try JSONDecoder().decode(ProjectSettings.self, from: json)
    #expect(settings.worktreeDirectory == "./.worktrees")
    #expect(settings.branchPrefix == nil)
    #expect(settings.effective(defaults: defaults).branchPrefix == "team/")
    #expect(settings.confirmsWorktreeRemoval)
  }
}

@Suite
struct WorktreeSettingsExpansionTests {
  private let project = Project(path: URL(fileURLWithPath: "/w/repo"))

  @Test func tildeExpandsToTheHomeDirectory() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    #expect(
      WorktreeSettings(worktreeDirectory: "~/trees").worktreeContainer(for: project).path
        == "\(home)/trees")
    #expect(WorktreeSettings(worktreeDirectory: "~").worktreeContainer(for: project).path == home)
  }

  @Test func projectPlaceholderWorksInAbsolutePaths() {
    let settings = WorktreeSettings(worktreeDirectory: "/srv/trees/{project}")
    #expect(settings.worktreeContainer(for: project).path == "/srv/trees/repo")
  }

  @Test func aTildeInTheMiddleIsNotExpanded() {
    let settings = WorktreeSettings(worktreeDirectory: "odd~name")
    #expect(settings.worktreeContainer(for: project).path == "/w/repo/odd~name")
  }
}
