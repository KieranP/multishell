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

  @Test func aStoredBlankIsNoPreferredAgentSoItsSwitchesGreyAsTheyCountOff() {
    let harness = Harness()
    harness.store.setPreferredAgent("")

    #expect(!harness.model.hasPreferredAgent)
    #expect(harness.model.preferredAgentNeededCaption != nil)
  }

  @Test func aSwitchGreyedForWantOfAnAgentSaysWhereToPickOne() {
    let harness = Harness()
    #expect(
      harness.model.preferredAgentNeededCaption
        == "Needs a preferred agent. Pick one in All Projects > Agents > Preferred agent."
    )
    #expect(harness.model.agentNeededCaption(in: harness.project)?.contains("Agents") == true)

    harness.model.setPreferredAgent("claude")

    #expect(harness.model.preferredAgentNeededCaption == nil)
    #expect(harness.model.agentNeededCaption(in: harness.project) == nil)
  }

  @Test func aProjectHasAnAgentFromTheGlobalOrItsOwnUnlessItOptsOut() {
    let harness = Harness()
    #expect(!harness.model.hasAgent(in: harness.project))

    harness.model.setSettings(ProjectSettings(preferredAgentID: "codex"), for: harness.project)
    #expect(harness.model.hasAgent(in: harness.project))

    harness.model.setPreferredAgent("claude")
    harness.model.setSettings(ProjectSettings(preferredAgentID: "none"), for: harness.project)
    #expect(!harness.model.hasAgent(in: harness.project))
  }
}
