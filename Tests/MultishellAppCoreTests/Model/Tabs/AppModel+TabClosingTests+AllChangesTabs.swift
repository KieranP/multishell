import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelTabClosingTests {
  @Test(arguments: [false, true])
  func closePaneAndCloseTabEachCloseTheAllChangesTabWhole(closesTheTab: Bool) throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))

    if closesTheTab { harness.model.closeActiveTab() } else { harness.model.closeActivePane() }

    #expect(harness.model.workspace.allChangesTab(tab.id) == nil)
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 1, "the shell stays")
    #expect(harness.model.pendingClose == nil)
  }

  @Test func aMiddleClickClosesTheAllChangesTabInTheBackground() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.newTab()

    harness.model.closeTab(tab.id)

    #expect(harness.model.workspace.allChangesTabs.isEmpty)
  }
}
