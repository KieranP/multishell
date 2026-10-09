import Foundation
import Testing

@testable import MultishellCore

struct TerminalTabTests {
  @Test func aTabWithoutACustomTitleHasNone() throws {
    let session = UUID()
    let tab = try decodeJSON(TerminalTab.self, tabJSON(worktree: "/repo", session: session))
    #expect(tab.customTitle == nil)
    #expect(tab.root == .terminal(session))
  }

  /// Every tab of a state file written before groups existed. The tabs and
  /// their panes must survive; the group is `repair`'s to supply.
  @Test func aTabWithoutAGroupDecodesAsUnassigned() throws {
    let session = UUID()
    let tab = try decodeJSON(TerminalTab.self, tabJSON(session: session))
    #expect(tab.groupID == TabGroup.unassigned)
    #expect(tab.sessionIDs == [session])
  }
}
