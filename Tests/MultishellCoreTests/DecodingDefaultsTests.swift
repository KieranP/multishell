import Foundation
import Testing

@testable import MultishellCore

/// Every persisted type must load from JSON written before its newest field
/// existed. One test per type added since `PersistenceTests`.
@Suite
struct DecodingDefaultsTests {
  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
  }

  @Test func appearanceWithoutUIFontSize() throws {
    let appearance = try decode(
      Appearance.self, #"{ "themeID": "multishell.light", "fontSize": 15 }"#)
    #expect(appearance.themeID == "multishell.light")
    #expect(appearance.fontSize == 15)
    #expect(appearance.uiFontSize == Appearance.defaultUIFontSize)
    #expect(appearance.fontName == nil)
  }

  @Test func worktreeSettingsFromAnEmptyObject() throws {
    let settings = try decode(WorktreeSettings.self, "{}")
    #expect(settings == WorktreeSettings())
  }

  @Test func tabWithoutCustomTitle() throws {
    let session = UUID()
    let tab = try decode(
      TerminalTab.self,
      #"""
      { "id": "\#(UUID().uuidString)", "worktreeID": "/repo",
        "root": { "terminal": { "_0": "\#(session.uuidString)" } },
        "focusedSessionID": "\#(session.uuidString)" }
      """#)
    #expect(tab.customTitle == nil)
    #expect(tab.root == .terminal(session))
  }

  @Test func worktreeURLsDecodeAsDirectories() throws {
    // Written by an older build without the trailing slash Foundation uses
    // for directories. Identity and relative resolution must not change.
    let worktree = try decode(
      Worktree.self,
      #"{ "path": "file:///repos/demo", "projectID": "/repos/demo", "head": "abc", "isPrimary": true, "isLocked": false }"#
    )
    #expect(worktree.id == "/repos/demo")
    #expect(worktree.branch == nil)
    #expect(worktree.isDetached)
    #expect(worktree.path.hasDirectoryPath)
  }

  @Test func workspaceFromTheVeryFirstBuildAndFromToday() throws {
    let today = Workspace()
    let roundTripped = try decode(
      Workspace.self, String(decoding: JSONEncoder().encode(today), as: UTF8.self))
    #expect(roundTripped == today)

    let ancient = try decode(Workspace.self, "{}")
    #expect(ancient == Workspace())
  }
}
