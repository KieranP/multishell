import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelRenameAgentChoiceTests {
  @Test func aStoredModelOrEffortTheCatalogueNoLongerListsStaysListed() {
    let harness = Harness()
    harness.store.setRenameAgent("codex")
    harness.store.setRenameModel("gpt-4-retired")
    harness.store.setRenameEffort("ludicrous")

    #expect(harness.model.renameModelOptions.map(\.id).contains("gpt-4-retired"))
    #expect(harness.model.renameEffortOptions.map(\.id).contains("ludicrous"))
  }

  @Test func theDefaultRowsLeadAndNoCustomCommandIsOffered() {
    let harness = Harness()
    harness.model.setRenameAgent("claude")

    #expect(harness.model.renameAgentOptions.first?.id == AppModel<FakeSurface>.renameUnsetID)
    #expect(!harness.model.renameAgentOptions.map(\.id).contains(AgentCatalogue.customID))
    #expect(harness.model.renameModelOptions.first?.id == AppModel<FakeSurface>.renameUnsetID)
    #expect(
      harness.model.renameEffortOptions.map(\.id).dropFirst() == [
        "low", "medium", "high", "xhigh", "max",
      ]
    )
  }

  @Test func theModelAndEffortCanBeChosenOnlyWhereTheRenameAgentTakesThem() {
    let harness = Harness()
    #expect(!harness.model.canChooseRenameModel && !harness.model.canChooseRenameEffort)

    harness.model.setRenameAgent("gemini")
    harness.store.setRenameEffort("high")
    #expect(harness.model.canChooseRenameModel)
    #expect(!harness.model.canChooseRenameEffort, "a stored effort Gemini takes no flag for")

    harness.model.setRenameAgent("codex")
    #expect(harness.model.canChooseRenameModel && harness.model.canChooseRenameEffort)
  }
}
