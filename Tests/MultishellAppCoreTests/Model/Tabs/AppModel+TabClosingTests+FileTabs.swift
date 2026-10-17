import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelTabClosingTests {
  @Test(arguments: [false, true])
  func closePaneAndCloseTabEachCloseAFileTabWhole(closesTheTab: Bool) {
    let harness = Harness()
    let file = harness.openFileTab()

    if closesTheTab { harness.model.closeActiveTab() } else { harness.model.closeActivePane() }

    #expect(harness.model.workspace.fileTab(file.id) == nil)
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 1, "the shell stays")
    #expect(harness.model.pendingClose == nil, "a file tab never asks")
  }

  @Test func aMiddleClickClosesAFileTabInTheBackground() {
    let harness = Harness()
    let file = harness.openFileTab()
    let shell = harness.model.workspace.tabs(in: harness.main.id)[0]
    harness.model.activateTab(shell.id)

    harness.model.closeTab(file.id)

    #expect(harness.model.workspace.fileTabs.isEmpty)
    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.id == shell.id)
  }
}
