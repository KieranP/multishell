import Foundation
import Testing

@testable import MultishellCore

@Suite
struct AgentFlagResolutionTests {
  private let project = Project(path: URL(fileURLWithPath: "/repos/a"))

  @Test func aProjectsFlagsOverrideTheGlobalOnesForItsAgent() {
    var workspace = Workspace()
    workspace.preferredAgentID = AgentCatalogue.claudeID
    workspace.agentFlags = ["claude": "--model opus", "codex": "--full-auto"]

    #expect(workspace.agentFlags(for: project, agent: "claude") == "--model opus")
    #expect(workspace.agentFlags(for: project, agent: "codex") == "--full-auto")
    #expect(workspace.agentFlags(for: project, agent: "opencode") == "", "nothing stored")

    let quiet = Project(path: project.path, settings: ProjectSettings(agentFlags: ""))
    #expect(quiet.settings.agentFlags != nil, "blank is an override, not an absent key")
    #expect(
      workspace.agentFlags(for: quiet, agent: "claude") == "",
      "a project can run the agent bare under a global that passes flags")

    let own = Project(path: project.path, settings: ProjectSettings(agentFlags: "--model haiku"))
    #expect(workspace.agentFlags(for: own, agent: "claude") == "--model haiku")
  }

  /// The settings field writes on every keystroke, so the space between two
  /// flags has to survive being typed; only an empty line drops the entry.
  @Test @MainActor func storingFlagsKeepsWhatWasTypedAndClearingRemovesTheEntry() {
    let store = WorkspaceStore()
    store.setAgentFlags("--model opus ", for: "claude")
    #expect(store.workspace.agentFlags["claude"] == "--model opus ")
    store.setAgentFlags(" ", for: "claude")
    #expect(store.workspace.agentFlags["claude"] == " ", "a space is a flag half typed")
    store.setAgentFlags("", for: "claude")
    #expect(store.workspace.agentFlags["claude"] == nil, "cleared, so nothing is left behind")
  }
}
