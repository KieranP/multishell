import Foundation
import MultishellCore
import MultishellGitKit
import Testing

@testable import MultishellAppCore

/// The New Worktree sheet's rules, without the sheet. A load is what git
/// says about a project; the picker may have moved by the time it lands.
@Suite
struct NewWorktreeDraftTests {
  private let a = "/repos/a"
  private let b = "/repos/b"

  private func loaded(_ id: String, branch: String = "feat") -> NewWorktreeDraft {
    var draft = NewWorktreeDraft(projectID: id)
    draft.branch = branch
    draft.beginLoading()
    draft.finishLoading(
      id, hasCommits: true, branches: ["main", "release", "spike"], remoteBranches: ["origin/main"],
      currentBranch: "main", checkedOut: ["main"])
    return draft
  }

  @Test func nothingCanBeCreatedUntilThePickedProjectHasLoaded() {
    var draft = NewWorktreeDraft(projectID: a)
    draft.branch = "feat"
    #expect(!draft.canCreate(checkedOut: []), "no load yet")

    draft.beginLoading()
    #expect(!draft.canCreate(checkedOut: []), "loading")

    draft.finishLoading(
      a, hasCommits: true, branches: ["main"], remoteBranches: [], currentBranch: "main",
      checkedOut: ["main"])
    #expect(draft.canCreate(checkedOut: ["main"]))
    #expect(draft.startPoint == "main")
  }

  /// The bug this guards against: a switch cancelled the first project's
  /// load, whose late return then cleared a "loading" flag while the second
  /// project's load was still running.
  @Test func aLateLoadForAnotherProjectIsIgnoredAndDoesNotEnableCreate() {
    var draft = NewWorktreeDraft(projectID: a)
    draft.branch = "feat"
    draft.beginLoading()
    draft.projectID = b
    draft.beginLoading()

    draft.finishLoading(
      a, hasCommits: true, branches: ["old"], remoteBranches: [], currentBranch: "old",
      checkedOut: [])

    #expect(!draft.canCreate(checkedOut: []))
    #expect(draft.branches.isEmpty && draft.baseBranch.isEmpty, "nothing of a's arrived")
    #expect(draft.startPoint == nil, "git gets HEAD, never the other project's branch")

    draft.finishLoading(
      b, hasCommits: true, branches: ["dev"], remoteBranches: [], currentBranch: "dev",
      checkedOut: [])
    #expect(draft.canCreate(checkedOut: []))
    #expect(draft.startPoint == "dev")
  }

  @Test func switchingProjectsKeepsTheTypedNameAndDropsTheRest() {
    var draft = loaded(a)
    draft.projectID = b
    draft.beginLoading()

    #expect(draft.branch == "feat", "the name is the user's")
    #expect(draft.branches.isEmpty && draft.remoteBranches.isEmpty)
    #expect(draft.baseBranch.isEmpty && draft.hasCommits)
    #expect(draft.availableBranches(checkedOut: []).isEmpty)
  }

  @Test func branchesCheckedOutElsewhereAreNotOffered() {
    let draft = loaded(a)
    #expect(draft.availableBranches(checkedOut: ["main"]) == ["release", "spike"])
    #expect(draft.availableBranches(checkedOut: ["main", "spike"]) == ["release"])
  }

  @Test func aNewBranchNeedsANameAndAnExistingOneNeedsAnAvailableChoice() {
    var draft = loaded(a, branch: "   ")
    #expect(!draft.canCreate(checkedOut: ["main"]))
    draft.branch = "feat"
    #expect(draft.canCreate(checkedOut: ["main"]))

    draft.createBranch = false
    draft.branch = "main"
    #expect(!draft.canCreate(checkedOut: ["main"]), "checked out already")
    draft.branch = "release"
    #expect(draft.canCreate(checkedOut: ["main"]))
    #expect(draft.startPoint == nil, "an existing branch has no start point")
  }

  @Test func switchingModesKeepsTheTypedNameAndNeverCarriesAPickedOne() {
    var draft = loaded(a, branch: "feat")
    draft.createBranch = false
    draft.modeChanged(checkedOut: ["main"])
    #expect(draft.branch == "release", "a typed name is not an existing branch; take the first")

    draft.branch = "spike"
    draft.createBranch = true
    draft.modeChanged(checkedOut: ["main"])
    #expect(draft.branch == "feat", "what was typed comes back, not what was picked")

    draft.branch = "release"
    draft.createBranch = false
    draft.modeChanged(checkedOut: ["main"])
    #expect(draft.branch == "release", "a typed name that is an existing branch is the choice")
  }

  @Test func togglingModesWhileALoadIsRunningDoesNotLoseTheTypedName() {
    var draft = NewWorktreeDraft(projectID: a)
    draft.branch = "feat"
    draft.beginLoading()

    draft.createBranch = false
    draft.modeChanged(checkedOut: [])
    #expect(draft.branch == "", "nothing to pick yet")
    draft.createBranch = true
    draft.modeChanged(checkedOut: [])

    #expect(draft.branch == "feat")
  }

  @Test func loadingInExistingModeReplacesAChoiceTheProjectDoesNotHave() {
    var draft = NewWorktreeDraft(projectID: a)
    draft.createBranch = false
    draft.branch = "elsewhere"
    draft.beginLoading()
    draft.finishLoading(
      a, hasCommits: true, branches: ["main", "release"], remoteBranches: [], currentBranch: "main",
      checkedOut: ["main"])
    #expect(draft.branch == "release")
  }

  @Test func aRepositoryWithoutCommitsCannotGetAWorktree() {
    var draft = NewWorktreeDraft(projectID: a)
    draft.branch = "feat"
    draft.beginLoading()
    draft.finishLoading(
      a, hasCommits: false, branches: [], remoteBranches: [], currentBranch: "HEAD", checkedOut: [])
    #expect(!draft.canCreate(checkedOut: []))
  }

  @Test func aRemovedProjectClearsThePickerAndAnotherDoesNot() {
    var draft = loaded(a)
    draft.projectsChanged(to: [a, b])
    #expect(draft.projectID == a)
    draft.projectsChanged(to: [b])
    #expect(draft.projectID == nil)
    #expect(!draft.canCreate(checkedOut: []))
  }

  @Test func aRepositoryWithOnlyItsCheckedOutBranchHasNothingToPick() {
    var draft = NewWorktreeDraft(projectID: a)
    draft.createBranch = false
    draft.beginLoading()
    draft.finishLoading(
      a, hasCommits: true, branches: ["main"], remoteBranches: ["origin/main", "origin/feature"],
      currentBranch: "main", checkedOut: ["main"])

    #expect(
      draft.availableBranches(checkedOut: ["main"]).isEmpty, "remote branches are not offered")
    #expect(draft.branch == "")
    #expect(!draft.canCreate(checkedOut: ["main"]))
    draft.createBranch = true
    draft.modeChanged(checkedOut: ["main"])
    draft.branch = "feature"
    #expect(draft.canCreate(checkedOut: ["main"]), "a new branch is the way")
  }

  @Test func pickerLabelsUseThePathOnlyWhenNamesCollide() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let projects = [
      Project(path: URL(fileURLWithPath: "\(home)/Work/api")),
      Project(path: URL(fileURLWithPath: "/srv/clients/acme/api")),
      Project(path: URL(fileURLWithPath: "\(home)/Work/web")),
    ]

    let labels = NewWorktreeDraft.labels(for: projects)

    #expect(labels[projects[0].id] == "api  (~/Work/api)")
    #expect(labels[projects[1].id] == "api  (/srv/clients/acme/api)")
    #expect(labels[projects[2].id] == "web")
  }

  @Test func aRepeatedProjectDoesNotTrapTheLabels() {
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    let labels = NewWorktreeDraft.labels(for: [project, project])
    #expect(labels == [project.id: "demo  (/repos/demo)"])
  }

  @Test func theProgressTextNamesTheStageOrTheTailAfterIt() {
    #expect(NewWorktreeDraft.progressText(for: .preCreateHook) == "Running the pre-create hook…")
    #expect(NewWorktreeDraft.progressText(for: .addingWorktree) == "Running git worktree add…")
    #expect(NewWorktreeDraft.progressText(for: .postCreateHook) == "Running the post-create hook…")
    #expect(NewWorktreeDraft.progressText(for: nil) == "Creating the worktree…")
  }

  @Test func creatingLocksTheDraft() {
    var draft = loaded(a)
    #expect(draft.canCreate(checkedOut: ["main"]))
    draft.isCreating = true
    #expect(!draft.canCreate(checkedOut: ["main"]))
  }
}
