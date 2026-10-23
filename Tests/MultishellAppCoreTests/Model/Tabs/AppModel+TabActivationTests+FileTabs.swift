import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelTabActivationTests {
  @Test func nextAndPreviousTabStepThroughFileTabsInStripOrder() throws {
    let harness = Harness()
    let file = harness.openFileTab()
    let shell = try #require(harness.model.workspace.tabs(in: harness.main.id).first)

    harness.model.activateNextTab()
    #expect(harness.model.workspace.activeWorkspaceTab(in: harness.main.id)?.id == shell.id)
    harness.model.activatePreviousTab()
    #expect(harness.model.workspace.activeWorkspaceTab(in: harness.main.id)?.id == file.id)
  }
}
