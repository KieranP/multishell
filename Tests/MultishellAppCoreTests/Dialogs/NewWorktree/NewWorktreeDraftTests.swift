import Foundation
import MultishellGitKit
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// A load is what git says about a project; the picker may have moved by the
/// time it lands.
@Suite
struct NewWorktreeDraftTests {
  private let firstProject = "/repos/a"
  private let secondProject = "/repos/b"

  private func loaded(_ id: String, branch: String = "feat") -> NewWorktreeDraft {
    var draft = NewWorktreeDraft(projectID: id)
    draft.branch = branch
    draft.beginLoading()
    draft.finishLoading(
      id,
      with: NewWorktreeBranches(
        hasCommits: true,
        localBranches: ["main", "release", "spike"],
        remoteBranches: ["origin/main"],
        currentBranch: "main",
      ),
      checkedOut: ["main"],
    )
    return draft
  }

  @Test func nothingCanBeCreatedUntilThePickedProjectHasLoaded() {
    var draft = NewWorktreeDraft(projectID: firstProject)
    draft.branch = "feat"
    #expect(!draft.canCreate(checkedOut: []), "no load yet")

    draft.beginLoading()
    #expect(!draft.canCreate(checkedOut: []), "loading")

    draft.finishLoading(
      firstProject,
      with: NewWorktreeBranches(
        hasCommits: true,
        localBranches: ["main"],
        remoteBranches: [],
        currentBranch: "main",
      ),
      checkedOut: ["main"],
    )
    #expect(draft.canCreate(checkedOut: ["main"]))
    #expect(draft.startPoint == "main")
  }

  /// A switch used to cancel the first project's load, whose late return cleared a "loading"
  /// flag while the second project's load was still running.
  @Test func aLateLoadForAnotherProjectIsIgnoredAndDoesNotEnableCreate() {
    var draft = NewWorktreeDraft(projectID: firstProject)
    draft.branch = "feat"
    draft.beginLoading()
    draft.projectID = secondProject
    draft.beginLoading()

    draft.finishLoading(
      firstProject,
      with: NewWorktreeBranches(
        hasCommits: true,
        localBranches: ["old"],
        remoteBranches: [],
        currentBranch: "old",
      ),
      checkedOut: [],
    )

    #expect(!draft.canCreate(checkedOut: []))
    #expect(
      draft.localBranches.isEmpty && draft.baseBranch.isEmpty,
      "nothing of firstProject's arrived",
    )
    #expect(draft.startPoint == nil, "git gets HEAD, never the other project's branch")

    draft.finishLoading(
      secondProject,
      with: NewWorktreeBranches(
        hasCommits: true,
        localBranches: ["dev"],
        remoteBranches: [],
        currentBranch: "dev",
      ),
      checkedOut: [],
    )
    #expect(draft.canCreate(checkedOut: []))
    #expect(draft.startPoint == "dev")
  }

  @Test func switchingProjectsKeepsTheTypedNameAndDropsTheRest() {
    var draft = loaded(firstProject)
    draft.projectID = secondProject
    draft.beginLoading()

    #expect(draft.branch == "feat", "the name is the user's")
    #expect(draft.localBranches.isEmpty && draft.remoteBranches.isEmpty)
    #expect(draft.baseBranch.isEmpty && draft.hasCommits)
    #expect(draft.availableBranches(checkedOut: []).isEmpty)
  }

  @Test func branchesCheckedOutElsewhereAreNotOffered() {
    let draft = loaded(firstProject)
    #expect(draft.availableBranches(checkedOut: ["main"]) == ["release", "spike"])
    #expect(draft.availableBranches(checkedOut: ["main", "spike"]) == ["release"])
  }

  @Test func aNewBranchNeedsANameAndAnExistingOneNeedsAnAvailableChoice() {
    var draft = loaded(firstProject, branch: "   ")
    #expect(!draft.canCreate(checkedOut: ["main"]))
    draft.branch = "feat"
    #expect(draft.canCreate(checkedOut: ["main"]))

    draft.createsBranch = false
    draft.branch = "main"
    #expect(!draft.canCreate(checkedOut: ["main"]), "checked out already")
    draft.branch = "release"
    #expect(draft.canCreate(checkedOut: ["main"]))
    #expect(draft.startPoint == nil, "an existing branch has no start point")
  }

  @Test func switchingModesKeepsTheTypedNameAndNeverCarriesAPickedOne() {
    var draft = loaded(firstProject, branch: "feat")
    draft.createsBranch = false
    draft.fitBranchToMode(checkedOut: ["main"])
    #expect(draft.branch == "release", "a typed name is not an existing branch; take the first")

    draft.branch = "spike"
    draft.createsBranch = true
    draft.fitBranchToMode(checkedOut: ["main"])
    #expect(draft.branch == "feat", "what was typed comes back, not what was picked")

    draft.branch = "release"
    draft.createsBranch = false
    draft.fitBranchToMode(checkedOut: ["main"])
    #expect(draft.branch == "release", "a typed name that is an existing branch is the choice")
  }

  @Test func togglingModesWhileALoadIsRunningDoesNotLoseTheTypedName() {
    var draft = NewWorktreeDraft(projectID: firstProject)
    draft.branch = "feat"
    draft.beginLoading()

    draft.createsBranch = false
    draft.fitBranchToMode(checkedOut: [])
    #expect(draft.branch == "", "nothing to pick yet")
    draft.createsBranch = true
    draft.fitBranchToMode(checkedOut: [])

    #expect(draft.branch == "feat")
  }

  @Test func loadingInExistingModeReplacesAChoiceTheProjectDoesNotHave() {
    var draft = NewWorktreeDraft(projectID: firstProject)
    draft.createsBranch = false
    draft.branch = "elsewhere"
    draft.beginLoading()
    draft.finishLoading(
      firstProject,
      with: NewWorktreeBranches(
        hasCommits: true,
        localBranches: ["main", "release"],
        remoteBranches: [],
        currentBranch: "main",
      ),
      checkedOut: ["main"],
    )
    #expect(draft.branch == "release")
  }

  @Test func aRepositoryWithoutCommitsCannotGetAWorktree() {
    var draft = NewWorktreeDraft(projectID: firstProject)
    draft.branch = "feat"
    draft.beginLoading()
    draft.finishLoading(
      firstProject,
      with: NewWorktreeBranches(
        hasCommits: false,
        localBranches: [],
        remoteBranches: [],
        currentBranch: "HEAD",
      ),
      checkedOut: [],
    )
    #expect(!draft.canCreate(checkedOut: []))
  }

  @Test func aRemovedProjectClearsThePickerAndAnotherDoesNot() {
    var draft = loaded(firstProject)
    draft.forgetProject(unlessIn: [firstProject, secondProject])
    #expect(draft.projectID == firstProject)
    draft.forgetProject(unlessIn: [secondProject])
    #expect(draft.projectID == nil)
    #expect(!draft.canCreate(checkedOut: []))
  }

  @Test func aRepositoryWithOnlyItsCheckedOutBranchHasNothingToPick() {
    var draft = NewWorktreeDraft(projectID: firstProject)
    draft.createsBranch = false
    draft.beginLoading()
    draft.finishLoading(
      firstProject,
      with: NewWorktreeBranches(
        hasCommits: true,
        localBranches: ["main"],
        remoteBranches: ["origin/main", "origin/feature"],
        currentBranch: "main",
      ),
      checkedOut: ["main"],
    )

    #expect(
      draft.availableBranches(checkedOut: ["main"]).isEmpty,
      "remote branches are not offered",
    )
    #expect(draft.branch == "")
    #expect(!draft.canCreate(checkedOut: ["main"]))
    draft.createsBranch = true
    draft.fitBranchToMode(checkedOut: ["main"])
    draft.branch = "feature"
    #expect(draft.canCreate(checkedOut: ["main"]), "a new branch is the way")
  }

  @Test func creatingLocksTheDraft() {
    var draft = loaded(firstProject)
    #expect(draft.canCreate(checkedOut: ["main"]))
    draft.isCreating = true
    #expect(!draft.canCreate(checkedOut: ["main"]))
  }
  /// Create used to take any non-empty name, so the hook ran and git then
  /// refused it.
  @Test func createIsOffForANameGitWillNotTake() {
    let project = "/w/repo"
    var draft = NewWorktreeDraft(projectID: project)
    draft.finishLoading(
      project,
      with: NewWorktreeBranches(
        hasCommits: true,
        localBranches: ["main"],
        remoteBranches: [],
        currentBranch: "main",
      ),
      checkedOut: [],
    )

    for refused in ["my branch", "foo..bar", "feat.lock", "-leading", "a~b"] {
      draft.branch = refused
      #expect(!draft.canCreate(checkedOut: []), "\(refused)")
      #expect(draft.branchNameIsRefused, "\(refused)")
    }
    draft.branch = "feat/tabs"
    #expect(draft.canCreate(checkedOut: []))
    #expect(!draft.branchNameIsRefused)
    draft.branch = "  "
    #expect(!draft.canCreate(checkedOut: []))
    #expect(!draft.branchNameIsRefused, "an empty field is not yet wrong")
  }

  @Test func theAllCheckedOutNoteWaitsForTheLoadAndThenForAnEmptyList() {
    var draft = NewWorktreeDraft(projectID: firstProject)
    draft.beginLoading()
    #expect(!draft.showsAllCheckedOutNote(checkedOut: ["main"]), "loading")

    draft.finishLoading(
      firstProject,
      with: NewWorktreeBranches(
        hasCommits: true,
        localBranches: ["main"],
        remoteBranches: [],
        currentBranch: "main",
      ),
      checkedOut: ["main"],
    )

    #expect(draft.showsAllCheckedOutNote(checkedOut: ["main"]))
    #expect(!draft.showsAllCheckedOutNote(checkedOut: []))
    draft.projectID = nil
    #expect(!draft.showsAllCheckedOutNote(checkedOut: ["main"]), "no project picked")
  }
}
