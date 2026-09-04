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

  @Test func aSplitWithoutWeightsGetsEqualShares() throws {
    let a = UUID()
    let b = UUID()
    let node = try decode(
      PaneNode.self,
      #"""
      { "split": { "axis": "horizontal", "children": [
        { "terminal": { "_0": "\#(a.uuidString)" } },
        { "terminal": { "_0": "\#(b.uuidString)" } } ] } }
      """#)
    #expect(node == .split(axis: .horizontal, children: [.terminal(a), .terminal(b)]))
  }

  @Test func weightsThatDoNotMatchTheChildrenAreReplacedNotTrusted() throws {
    // `removing` zips children with weights; a short list would drop a pane.
    let a = UUID()
    let b = UUID()
    for weights in ["[1]", "[1, 2, 3]", "[1, -1]"] {
      let node = try decode(
        PaneNode.self,
        #"""
        { "split": { "axis": "vertical", "weights": \#(weights), "children": [
          { "terminal": { "_0": "\#(a.uuidString)" } },
          { "terminal": { "_0": "\#(b.uuidString)" } } ] } }
        """#)
      #expect(
        node == .split(axis: .vertical, children: [.terminal(a), .terminal(b)]), "\(weights)")
    }
  }

  @Test func paneTreesRoundTripThroughTheSynthesizedEncoder() throws {
    let tree = PaneNode.split(
      axis: .vertical,
      children: [
        .terminal(UUID()),
        .split(
          axis: .horizontal, children: [.terminal(UUID()), .terminal(UUID())], weights: [3, 1]),
      ],
      weights: [0.25, 0.75])
    let json = try JSONEncoder().encode(tree)
    #expect(try JSONDecoder().decode(PaneNode.self, from: json) == tree)
  }

  @Test func aThemeWithTheWrongNumberOfColoursIsRefused() throws {
    var fifteen = Theme.multishellDark
    fifteen.ansi.removeLast()
    let json = try JSONEncoder().encode(fifteen)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(Theme.self, from: json) }
    let full = try JSONEncoder().encode(Theme.multishellDark)
    #expect(try JSONDecoder().decode(Theme.self, from: full) == Theme.multishellDark)
  }

  @Test func anEngineThisBuildDoesNotKnowFallsBackRatherThanFailingTheFile() throws {
    // Written by a newer build with a third engine. Losing the engine choice
    // is fine; losing every project is not.
    let workspace = try decode(
      Workspace.self,
      #"{ "terminalEngine": "wezterm", "projects": [ { "path": "file:///repos/demo/" } ] }"#)
    #expect(workspace.terminalEngine == .ghostty)
    #expect(workspace.projects.map(\.name) == ["demo"])
  }

  @Test func anUnknownSplitAxisFallsBackToHorizontal() throws {
    let a = UUID()
    let b = UUID()
    let node = try decode(
      PaneNode.self,
      #"""
      { "split": { "axis": "diagonal", "children": [
        { "terminal": { "_0": "\#(a.uuidString)" } },
        { "terminal": { "_0": "\#(b.uuidString)" } } ] } }
      """#)
    #expect(node == .split(axis: .horizontal, children: [.terminal(a), .terminal(b)]))
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
