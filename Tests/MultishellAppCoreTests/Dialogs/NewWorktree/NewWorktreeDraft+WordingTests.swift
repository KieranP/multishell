import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct NewWorktreeDraftWordingTests {
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
    #expect(NewWorktreeDraft.progressText(for: nil) == "Creating the worktree…")
  }

  @Test func createNamesTheAgentItStartsAndIsPlainWithoutOne() {
    var draft = NewWorktreeDraft(projectID: "/repos/a")
    draft.fitAgent(
      startsByDefault: true, preferred: "claude", offered: ["claude", AgentCatalogue.customID])
    #expect(draft.createTitle == "Create and Start Claude Code")

    draft.agentID = AgentCatalogue.customID
    #expect(draft.createTitle == "Create and Start Custom Command")

    draft.startsAgent = false
    #expect(draft.createTitle == "Create Worktree")
  }
}
