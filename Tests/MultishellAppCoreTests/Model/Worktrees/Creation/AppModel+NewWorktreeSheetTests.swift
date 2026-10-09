import Foundation
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
        == ["main", "feature"]
    )
    #expect(harness.model.checkedOutBranches(for: NewWorktreeDraft(projectID: nil)).isEmpty)
  }

  @Test func theBranchPrefixIsTheChosenProjectsEffectiveOneAndEmptyBeforeOneIsChosen() {
    let harness = Harness()
    harness.model.setWorktreeDefaults(WorktreeSettings(branchPrefix: "team/"))

    #expect(
      harness.model.branchPrefix(for: NewWorktreeDraft(projectID: harness.project.id)) == "team/"
    )
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

  @Test func theAgentSwitchStartsOnWhereTheProjectOrTheGlobalAutoStartsOnCreation() {
    let harness = Harness()
    harness.model.setPreferredAgent("codex")
    harness.model.agentDetection = AgentDetection(found: [
      "claude": URL(fileURLWithPath: "/bin/claude"), "codex": URL(fileURLWithPath: "/bin/codex"),
    ])
    var draft = NewWorktreeDraft(projectID: harness.project.id)

    harness.model.fitAgent(of: &draft)
    #expect(!draft.startsAgent && draft.agentID == "codex", "auto-start on creation is off")
    #expect(draft.offeredAgentIDs == ["claude", "codex"])

    harness.model.setAutoStartsAgentOnCreate(true)
    harness.model.fitAgent(of: &draft)
    #expect(draft.startsAgent, "the global turns it on")

    harness.model.setSettings(
      ProjectSettings(autoStartsAgentOnCreate: false),
      for: harness.project,
    )
    harness.model.fitAgent(of: &draft)
    #expect(!draft.startsAgent, "the project's own answer wins")

    harness.model.setSettings(
      ProjectSettings(preferredAgentID: "claude", autoStartsAgentOnCreate: true),
      for: harness.project,
    )
    harness.model.fitAgent(of: &draft)
    #expect(draft.startsAgent && draft.agentID == "claude", "on the project's own agent")
  }

  @Test func withNoProjectChosenTheAgentSwitchIsOff() {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    harness.model.setAutoStartsAgentOnCreate(true)
    var draft = NewWorktreeDraft(projectID: nil)

    harness.model.fitAgent(of: &draft)

    #expect(!draft.startsAgent)
  }
}
