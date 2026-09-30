import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelNewWorktreeSheetTests {
  @Test func theCheckedOutBranchesAreTheChosenProjectsAndNoneBeforeOneIsChosen() {
    let h = Harness()

    #expect(
      h.model.checkedOutBranches(for: NewWorktreeDraft(projectID: h.project.id))
        == ["main", "feature"])
    #expect(h.model.checkedOutBranches(for: NewWorktreeDraft(projectID: nil)).isEmpty)
  }

  @Test func theBranchPrefixIsTheChosenProjectsEffectiveOneAndEmptyBeforeOneIsChosen() {
    let h = Harness()
    h.model.setWorktreeDefaults(WorktreeSettings(branchPrefix: "team/"))

    #expect(h.model.branchPrefix(for: NewWorktreeDraft(projectID: h.project.id)) == "team/")
    #expect(h.model.branchPrefix(for: NewWorktreeDraft(projectID: nil)) == "")
  }

  /// The sheet's load, step for step, against a repository with spare
  /// branches: the existing-branch list must offer the ones not checked out.
  @Test func theExistingBranchListOffersTheUncheckedOutLocalBranches() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    _ = try await h.git.run(["branch", "release"], in: h.project.path)
    _ = try await h.git.run(["branch", "spike"], in: h.project.path)
    h.model.requestNewWorktree(in: h.project)
    let request = try #require(h.model.newWorktreeRequest)

    var draft = NewWorktreeDraft(projectID: request.projectID)
    draft.beginLoading()
    let project = try #require(h.model.workspace.project(request.projectID!))
    let read = try #require(await h.model.newWorktreeBranches(of: project))
    let checkedOut = Set(h.model.workspace.worktrees(of: project.id).compactMap(\.branch))
    draft.finishLoading(project.id, with: read, checkedOut: checkedOut)

    #expect(draft.availableBranches(checkedOut: checkedOut) == ["release", "spike"])
    draft.createBranch = false
    draft.modeChanged(checkedOut: checkedOut)
    #expect(draft.branch == "release")
    #expect(draft.canCreate(checkedOut: checkedOut))
  }

  @Test func thePlannedLocationPlacesTheTrimmedNameAndIsADashWithoutOne() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    var draft = NewWorktreeDraft(projectID: h.project.id)
    #expect(h.model.plannedLocation(for: draft) == "\u{2014}", "no name typed")

    draft.branch = "  feat/x "

    #expect(h.model.plannedLocation(for: draft).hasSuffix("/feat-x"))
    draft.projectID = nil
    #expect(h.model.plannedLocation(for: draft) == "\u{2014}", "no project picked")
  }
}
