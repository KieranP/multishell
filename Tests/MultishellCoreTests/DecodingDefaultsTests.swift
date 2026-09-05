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

  @Test func aSessionWithoutAnAgentIDIsAPlainShell() throws {
    let session = try decode(
      TerminalSession.self,
      #"{ "id": "\#(UUID().uuidString)", "worktreeID": "/w", "workingDirectory": "file:///w/", "title": "Shell" }"#
    )
    #expect(session.agentID == nil)
    #expect(session.command == nil)
  }

  @Test func aWorkspaceWithoutAgentOrNotificationFieldsGetsTheDefaults() throws {
    let workspace = try decode(Workspace.self, #"{ "projects": [] }"#)
    #expect(workspace.notifications == .off)
    #expect(workspace.preferredAgentID == nil)
    #expect(workspace.customAgentCommand == "")
    #expect(!workspace.autoStartAgent, "off until asked for")
  }

  @Test func aNotificationPreferenceThisBuildDoesNotKnowFallsBack() throws {
    let workspace = try decode(
      Workspace.self,
      #"{ "notifications": "whisper", "preferredAgentID": "future-agent", "projects": [ { "path": "file:///repos/demo/" } ] }"#
    )
    #expect(workspace.notifications == .off)
    #expect(workspace.preferredAgentID == "future-agent", "an unknown agent id is kept as text")
    #expect(workspace.projects.count == 1)
  }

  @Test func projectSettingsKeepAnUnknownAgentIdAndReadEmptyAsNoOverride() throws {
    let unknown = try decode(ProjectSettings.self, #"{ "preferredAgentID": "future-agent" }"#)
    #expect(unknown.preferredAgentID == "future-agent")
    let empty = try decode(ProjectSettings.self, #"{ "preferredAgentID": "" }"#)
    #expect(empty.preferredAgentID == nil)
    #expect(try decode(ProjectSettings.self, "{}").preferredAgentID == nil)
    #expect(try decode(ProjectSettings.self, "{}").autoStartAgent == nil, "follows the global")
    #expect(
      try decode(ProjectSettings.self, #"{ "autoStartAgent": false }"#).autoStartAgent == false)
  }

  @Test func projectSettingsWithoutTheNewerFieldsGetTheirDefaults() throws {
    let settings = try decode(ProjectSettings.self, #"{ "postCreateHook": "npm install" }"#)
    #expect(settings.preCreateHook == "" && settings.preDeleteHook == "")
    #expect(settings.postCreateHook == "npm install")
    #expect(settings.defaultShell == nil, "follows the global shell")
    #expect(settings.iconGlyph == nil && settings.iconTint == nil, "the folder, untinted")

    let shell = try decode(ProjectSettings.self, #"{ "defaultShell": "" }"#)
    #expect(shell.defaultShell == nil, "empty reads as no override, like the other strings")
    let login = try decode(ProjectSettings.self, #"{ "defaultShell": "login" }"#)
    #expect(login.defaultShell == ShellCatalogue.loginShellID)
  }

  @Test func anIconTintOutsideTheThemeOrOfTheWrongTypeIsDropped() throws {
    #expect(try decode(ProjectSettings.self, #"{ "iconTint": 16 }"#).iconTint == nil)
    #expect(try decode(ProjectSettings.self, #"{ "iconTint": -1 }"#).iconTint == nil)
    #expect(try decode(ProjectSettings.self, #"{ "iconTint": "red" }"#).iconTint == nil)
    #expect(try decode(ProjectSettings.self, #"{ "iconTint": 3 }"#).iconTint == 3)
    #expect(
      try decode(ProjectSettings.self, #"{ "iconGlyph": "🚀", "iconTint": 3 }"#).iconGlyph == "🚀")
  }

  @Test func aWorkspaceWithoutShellEditorOrSelectionFieldsGetsTheDefaults() throws {
    let workspace = try decode(Workspace.self, #"{ "projects": [] }"#)
    #expect(workspace.defaultShell == nil, "$SHELL")
    #expect(workspace.preferredEditorID == nil)
    #expect(workspace.customEditorCommand == "")
    #expect(workspace.opensTerminalOnSelect, "on until turned off")

    let chosen = try decode(
      Workspace.self,
      #"{ "defaultShell": "/opt/homebrew/bin/fish", "preferredEditorID": "future-editor", "opensTerminalOnSelect": false }"#
    )
    #expect(chosen.defaultShell == "/opt/homebrew/bin/fish")
    #expect(chosen.preferredEditorID == "future-editor", "an unknown editor id is kept as text")
    #expect(!chosen.opensTerminalOnSelect)
  }

  @Test func aSessionsShellIsRuntimeOnlyAndNeverSaved() throws {
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w"), title: "Shell",
      shell: "/bin/bash")
    let json = String(decoding: try JSONEncoder().encode(session), as: UTF8.self)
    #expect(!json.contains("/bin/bash"))
    let restored = try JSONDecoder().decode(TerminalSession.self, from: Data(json.utf8))
    #expect(restored.shell == nil, "a relaunched tab reads the setting again")
    #expect(restored.shellPath == ShellCatalogue.loginShellPath())
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

/// One broken element in a saved collection must cost that element, not the
/// file. Before this, a tab from a newer build with a pane kind this one did
/// not know moved the whole state aside and the sidebar came up empty.
@Suite
struct LossyDecodingTests {
  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
  }

  private func tabJSON(root: String) -> String {
    let session = UUID().uuidString
    return #"""
      { "id": "\#(UUID().uuidString)", "worktreeID": "/repos/demo",
        "root": \#(root), "focusedSessionID": "\#(session)" }
      """#
  }

  @Test func aTabWithAPaneKindFromANewerBuildIsDroppedAndTheProjectsKept() throws {
    let good = tabJSON(root: #"{ "terminal": { "_0": "\#(UUID().uuidString)" } }"#)
    let newer = tabJSON(root: #"{ "tabs": { "children": [] } }"#)
    let workspace = try decode(
      Workspace.self,
      #"""
      { "projects": [ { "path": "file:///repos/demo/" } ],
        "tabs": [ \#(good), \#(newer) ] }
      """#)

    #expect(workspace.projects.map(\.name) == ["demo"])
    #expect(workspace.tabs.count == 1)
  }

  @Test func badElementsOfEveryShapeAreSkippedWithoutStalling() throws {
    // A scalar, an object missing required keys, an invalid UUID, then a
    // sound element: the decoder must step past each bad one and finish.
    let sound = tabJSON(root: #"{ "terminal": { "_0": "\#(UUID().uuidString)" } }"#)
    let workspace = try decode(
      Workspace.self,
      #"""
      { "tabs": [ 7, "text", null, [1, 2], { }, { "id": "nope" }, \#(sound) ],
        "sessions": [ 1, { "id": "\#(UUID().uuidString)", "worktreeID": "/w",
                           "workingDirectory": "file:///w/", "title": "sh" } ],
        "worktrees": [ { "projectID": "/p" }, { "path": "file:///w/", "projectID": "/p" } ] }
      """#)

    #expect(workspace.tabs.count == 1)
    #expect(workspace.sessions.count == 1)
    #expect(workspace.worktrees.count == 1)
  }

  @Test func aCollectionThatIsNotAnArrayReadsAsEmpty() throws {
    let workspace = try decode(
      Workspace.self,
      #"{ "projects": [ { "path": "file:///repos/demo/" } ], "tabs": { "oops": 1 }, "sessions": 3 }"#
    )
    #expect(workspace.projects.count == 1)
    #expect(workspace.tabs.isEmpty && workspace.sessions.isEmpty)
  }

  @Test func aBrokenProjectStillFailsTheFileSoTheBackupIsKept() {
    #expect(throws: DecodingError.self) {
      try decode(Workspace.self, #"{ "projects": [ { "isExpanded": true } ] }"#)
    }
  }

  @Test func soundCollectionsDecodeExactlyAsBefore() throws {
    var workspace = Workspace()
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(path: project.path, projectID: project.id, head: "a", branch: "main")
    let session = TerminalSession(
      worktreeID: worktree.id, workingDirectory: worktree.path, title: "sh")
    workspace.projects = [project]
    workspace.worktrees = [worktree]
    workspace.sessions = [session]
    workspace.tabs = [TerminalTab(worktreeID: worktree.id, session: session.id)]

    let json = try JSONEncoder().encode(workspace)
    #expect(try JSONDecoder().decode(Workspace.self, from: json) == workspace)
  }
}
