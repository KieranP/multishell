import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabOpeningOnWorktreeTests {
  @Test func aMenusNewShellTabSelectsItsWorktreeAndOpensOnlyThatShell() throws {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    h.model.setAutoStartAgent(true)
    h.model.select(h.main)

    h.model.newShellTab(selecting: h.feature)

    #expect(h.model.workspace.selectedWorktreeID == h.feature.id)
    let tabs = h.model.workspace.tabs(in: h.feature.id)
    #expect(tabs.count == 1, "no first tab opened on the way")
    let session = try #require(h.model.workspace.session(tabs[0].focusedSessionID))
    #expect(session.agentID == nil)
  }

  @Test func aMenusNewAgentTabSelectsItsWorktreeAndStartsThePreferredAgent() throws {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    h.model.select(h.main)

    h.model.newAgentTab(selecting: h.feature)

    #expect(h.model.workspace.selectedWorktreeID == h.feature.id)
    let tabs = h.model.workspace.tabs(in: h.feature.id)
    #expect(tabs.count == 1)
    let session = try #require(h.model.workspace.session(tabs[0].focusedSessionID))
    #expect(session.agentID == "claude")
  }

  @Test func aWorktreeThatCannotBeSelectedGetsNoTab() throws {
    let h = Harness()
    h.model.select(h.main)
    try FileManager.default.removeItem(at: h.feature.path)

    h.model.newShellTab(selecting: h.feature)
    h.model.newAgentTab(selecting: h.feature)

    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
    #expect(h.model.workspace.tabs(in: h.feature.id).isEmpty)
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1, "nothing landed where it was")
  }
}
