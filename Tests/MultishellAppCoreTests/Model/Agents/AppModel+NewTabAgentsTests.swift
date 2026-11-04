import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelNewTabAgentsTests {
  @Test func theNewTabMenuListsWhatWasFoundAndTheCustomCommandOnlyWhenTyped() throws {
    let bin = try fakeBin(["codex", "claude"])
    defer { Scratch.remove(bin) }
    let harness = Harness()
    harness.model.agentDetection = AgentDetection(searchPath: bin.path)

    #expect(harness.model.newTabAgentIDs == ["claude", "codex"], "catalogue order")

    harness.model.setCustomAgentCommand("  ")
    #expect(harness.model.newTabAgentIDs == ["claude", "codex"], "a blank line is no agent")

    harness.model.setCustomAgentCommand("my-agent --fast")
    #expect(harness.model.newTabAgentIDs == ["claude", "codex", "custom"])

    let relaunched = harness.relaunched().model
    #expect(relaunched.newTabAgentIDs == ["custom"], "the saved command, before any PATH scan")
  }

  @Test func agentTabsAreOfferedOnceAnAgentIsFoundOrACommandTyped() throws {
    let bin = try fakeBin([])
    defer { Scratch.remove(bin) }
    let harness = Harness()
    harness.model.agentDetection = AgentDetection(searchPath: bin.path)
    #expect(!harness.model.offersAgentTabs)

    harness.model.setCustomAgentCommand("my-agent")
    #expect(harness.model.offersAgentTabs)

    let found = try fakeBin(["claude"])
    defer { Scratch.remove(found) }
    let another = Harness()
    another.model.agentDetection = AgentDetection(searchPath: found.path)
    #expect(another.model.offersAgentTabs)
  }
}
