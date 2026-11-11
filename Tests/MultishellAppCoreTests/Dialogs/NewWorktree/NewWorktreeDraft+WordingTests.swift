import Foundation
import MultishellGitKit
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct NewWorktreeDraftWordingTests {
  @Test func theProgressTextNamesTheStageOrTheTailAfterIt() {
    #expect(NewWorktreeDraft.progressText(for: .preCreateHook) == "Running the pre-create hook…")
    #expect(NewWorktreeDraft.progressText(for: .addingWorktree) == "Running git worktree add…")
    #expect(NewWorktreeDraft.progressText(for: nil) == "Creating the worktree…")
  }

  @Test func createNamesTheAgentItStartsAndIsPlainWithoutOne() {
    var draft = NewWorktreeDraft(projectID: "/repos/a")
    draft.fitAgent(
      startsByDefault: true,
      preferred: "claude",
      offered: ["claude", AgentCatalogue.customID],
    )
    #expect(draft.createTitle == "Create and Start Claude Code")

    draft.agentID = AgentCatalogue.customID
    #expect(draft.createTitle == "Create and Start Custom Command")

    draft.startsAgent = false
    #expect(draft.createTitle == "Create Worktree")
  }
}
