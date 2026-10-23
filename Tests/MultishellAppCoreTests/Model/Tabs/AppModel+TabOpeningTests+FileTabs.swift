import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelTabOpeningTests {
  @Test func aWorktreeHoldingOnlyFileTabsGetsNoShellWhenSelected() {
    let harness = Harness()
    harness.store.openFileTab(path: "README.md", in: harness.feature.id)

    harness.model.select(harness.feature)

    #expect(harness.model.workspace.tabs(in: harness.feature.id).isEmpty)
    #expect(harness.model.workspace.fileTabs(in: harness.feature.id).count == 1)
  }
}
