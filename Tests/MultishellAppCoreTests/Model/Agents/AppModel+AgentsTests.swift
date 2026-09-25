import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// Agent tabs: the store keeps an id.
@Suite @MainActor
struct AppModelAgentsTests {
  @Test func theProjectOverrideBeatsTheGlobalAndNoneMeansNoAgent() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    #expect(h.model.preferredAgentID(for: h.main) == "claude")

    h.model.updateSettings(ProjectSettings(preferredAgentID: "codex"), for: h.project)
    #expect(h.model.preferredAgentID(for: h.main) == "codex")

    h.model.updateSettings(ProjectSettings(preferredAgentID: "none"), for: h.project)
    #expect(h.model.preferredAgentID(for: h.main) == nil)
    h.model.select(h.main)
    let tabs = h.model.workspace.tabs(in: h.main.id).count
    h.model.presentedError = nil
    h.model.newAgentTab()
    #expect(h.model.workspace.tabs(in: h.main.id).count == tabs)
    #expect(h.model.presentedError?.title == "No agent chosen")
  }

  @Test func theNewTabMenuListsWhatWasFoundAndTheCustomCommandOnlyWhenTyped() throws {
    let bin = try fakeBin(["codex", "claude"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let h = Harness()
    h.model.agentDetection = AgentDetection(searchPath: bin.path)

    #expect(h.model.installedAgentIDs == ["claude", "codex"], "catalogue order")

    h.model.setCustomAgentCommand("  ")
    #expect(h.model.installedAgentIDs == ["claude", "codex"], "a blank line is no agent")

    h.model.setCustomAgentCommand("my-agent --fast")
    #expect(h.model.installedAgentIDs == ["claude", "codex", "custom"])

    // Its own store: a second model over the harness's would deselect the
    // worktree under it, `init` clearing the selection.
    let saved = WorkspaceStore(
      file: WorkspaceFile(
        fileURL: Scratch.path("relaunch").appendingPathComponent("state.json")))
    saved.setCustomAgentCommand("my-agent --fast")
    let relaunched = AppModel(
      store: saved, host: FakeEngine(), coordinator: nil, watcher: FakeWatcher())
    #expect(relaunched.installedAgentIDs == ["custom"], "the saved command, before any PATH scan")
  }

  @Test func theFlagsFooterSaysWhenTheGlobalLineIsEmpty() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    #expect(
      h.model.globalAgentFlagsCaption(for: h.project) == "Using the global flags, which are none.")

    h.model.setAgentFlags("--verbose", for: "claude")

    #expect(
      h.model.globalAgentFlagsCaption(for: h.project) == "Using the global flags, --verbose.")
  }

  @Test func theCustomCommandFieldShowsOnlyForTheCustomAgent() {
    let h = Harness()
    h.model.setPreferredAgent(AgentCatalogue.customID)
    #expect(h.model.usesCustomAgent)

    h.model.setPreferredAgent("claude")
    #expect(!h.model.usesCustomAgent)
  }

  @Test func autoStartHasSomethingToStartOnlyOnceAnAgentIsChosen() {
    let h = Harness()
    h.model.setPreferredAgent(AgentCatalogue.noneID)
    #expect(!h.model.hasPreferredAgent)

    h.model.setPreferredAgent("claude")
    #expect(h.model.hasPreferredAgent)
  }
}
