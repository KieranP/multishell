import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelNewWorktreeSheetTests {
  @Test func theCheckedOutBranchesAreTheChosenProjectsAndNoneBeforeOneIsChosen() {
    let harness = Harness()

    #expect(
      harness.model.checkedOutBranches(for: NewWorktreeDraft(projectID: harness.project.id))
        == ["main", "feature"])
    #expect(harness.model.checkedOutBranches(for: NewWorktreeDraft(projectID: nil)).isEmpty)
  }

  @Test func theBranchPrefixIsTheChosenProjectsEffectiveOneAndEmptyBeforeOneIsChosen() {
    let harness = Harness()
    harness.model.setWorktreeDefaults(WorktreeSettings(branchPrefix: "team/"))

    #expect(
      harness.model.branchPrefix(for: NewWorktreeDraft(projectID: harness.project.id)) == "team/")
    #expect(harness.model.branchPrefix(for: NewWorktreeDraft(projectID: nil)) == "")
  }

  @Test func theExistingBranchListOffersTheUncheckedOutLocalBranches() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await harness.git.run(["branch", "release"], in: harness.project.path)
    _ = try await harness.git.run(["branch", "spike"], in: harness.project.path)
    harness.model.requestNewWorktree(in: harness.project)
    let request = try #require(harness.model.newWorktreeRequest)

    var draft = NewWorktreeDraft(projectID: request.projectID)
    draft.beginLoading()
    let project = try #require(harness.model.workspace.project(request.projectID!))
    let read = try #require(await harness.model.newWorktreeBranches(of: project))
    let checkedOut = harness.model.checkedOutBranches(for: draft)
    draft.finishLoading(project.id, with: read, checkedOut: checkedOut)

    #expect(draft.availableBranches(checkedOut: checkedOut) == ["release", "spike"])
    draft.createsBranch = false
    draft.fitBranchToMode(checkedOut: checkedOut)
    #expect(draft.branch == "release")
    #expect(draft.canCreate(checkedOut: checkedOut))
  }

  @Test func thePlannedLocationPlacesTheTrimmedNameAndIsADashWithoutOne() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    var draft = NewWorktreeDraft(projectID: harness.project.id)
    #expect(harness.model.plannedLocation(for: draft) == "\u{2014}", "no name typed")

    draft.branch = "  feat/x "

    #expect(harness.model.plannedLocation(for: draft).hasSuffix("/feat-x"))
    draft.projectID = nil
    #expect(harness.model.plannedLocation(for: draft) == "\u{2014}", "no project picked")
  }
}
