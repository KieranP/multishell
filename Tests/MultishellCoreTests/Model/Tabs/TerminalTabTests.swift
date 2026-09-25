import Foundation
import Testing

@testable import MultishellCore

struct TerminalTabTests {
  @Test func aTabWithoutACustomTitleHasNone() throws {
    let session = UUID()
    let tab = try decodeJSON(
      TerminalTab.self,
      #"""
      { "id": "\#(UUID().uuidString)", "worktreeID": "/repo",
        "root": { "terminal": { "_0": "\#(session.uuidString)" } },
        "focusedSessionID": "\#(session.uuidString)" }
      """#)
    #expect(tab.customTitle == nil)
    #expect(tab.root == .terminal(session))
  }

  /// Every tab of a state file written before groups existed. The tabs and
  /// their panes must survive; the group is `repairReferences`' to supply.
  @Test func aTabWithoutAGroupDecodesAsUnassigned() throws {
    let session = UUID()
    let tab = try decodeJSON(
      TerminalTab.self,
      #"""
      { "id": "\#(UUID())", "worktreeID": "/repos/demo", "focusedSessionID": "\#(session)",
        "root": { "terminal": { "_0": "\#(session)" } } }
      """#)
    #expect(tab.groupID == TabGroup.unassigned)
    #expect(tab.sessionIDs == [session])
  }
}
