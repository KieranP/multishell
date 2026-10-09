import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelAgentChoiceTests {
  @Test func theProjectOverrideBeatsTheGlobalAndNoneMeansNoAgent() {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    #expect(harness.model.effectiveAgentID(for: harness.main) == "claude")

    harness.model.setSettings(ProjectSettings(preferredAgentID: "codex"), for: harness.project)
    #expect(harness.model.effectiveAgentID(for: harness.main) == "codex")

    harness.model.setSettings(ProjectSettings(preferredAgentID: "none"), for: harness.project)
    #expect(harness.model.effectiveAgentID(for: harness.main) == nil)
    harness.model.select(harness.main)
    let tabs = harness.model.workspace.tabs(in: harness.main.id).count
    harness.model.presentedError = nil
    harness.model.newAgentTab()
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == tabs)
    #expect(harness.model.presentedError?.title == "No agent chosen")
  }

  @Test func theFlagsFooterSaysWhenTheGlobalLineIsEmpty() {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    #expect(
      harness.model.globalAgentFlagsCaption(for: harness.project)
        == "Using the global flags, which are none."
    )

    harness.model.setAgentFlags("--verbose", for: "claude")

    #expect(
      harness.model.globalAgentFlagsCaption(for: harness.project)
        == "Using the global flags, --verbose."
    )
  }

  @Test func theCustomCommandFieldShowsOnlyForTheCustomAgent() {
    let harness = Harness()
    harness.model.setPreferredAgent(AgentCatalogue.customID)
    #expect(harness.model.usesCustomAgent)

    harness.model.setPreferredAgent("claude")
    #expect(!harness.model.usesCustomAgent)
  }

  @Test func theGlobalAgentIsNoneUntilOneIsChosen() {
    let harness = Harness()
    #expect(harness.model.globalAgentID == AgentCatalogue.noneID)
    #expect(!harness.model.hasPreferredAgent)

    harness.model.setPreferredAgent("claude")

    #expect(harness.model.globalAgentID == "claude")
    #expect(harness.model.hasPreferredAgent)
  }

  @Test func aStoredNoneIsNoPreferredAgent() {
    let harness = Harness()
    harness.store.setPreferredAgent(AgentCatalogue.noneID)

    #expect(harness.model.globalAgentID == AgentCatalogue.noneID)
    #expect(!harness.model.hasPreferredAgent)
  }
}
