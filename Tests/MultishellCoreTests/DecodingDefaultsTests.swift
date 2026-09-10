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

  /// A theme file written before the focus ring and the fade existed, and
  /// one that spells either as the wrong type. Both keys have to default,
  /// or every user theme file stops loading.
  @Test func aThemeWithoutAFocusRingOrAFadeStillLoads() throws {
    let bare = try decode(
      Theme.self,
      #"""
      { "id": "bare", "name": "Bare", "isDark": true, "background": "#000000",
        "foreground": "#ffffff", "cursor": "#ffffff", "selectionBackground": "#2f4f7a",
        "ansi": ["#000"\#(String(repeating: ",\"#000\"", count: 15))] }
      """#)
    #expect(bare.focusRing == nil)
    #expect(bare.focusRingRGB == bare.selectionRGB, "the key left out is the selection colour")
    #expect(bare.inactivePaneOpacity == 1, "nothing fades until a theme asks for it")

    let wrongTypes = try decode(
      Theme.self,
      #"""
      { "id": "odd", "name": "Odd", "isDark": true, "background": "#000000",
        "foreground": "#ffffff", "cursor": "#ffffff", "selectionBackground": "#2f4f7a",
        "focusRing": 12, "inactivePaneOpacity": "half",
        "ansi": ["#000"\#(String(repeating: ",\"#000\"", count: 15))] }
      """#)
    #expect(wrongTypes.focusRingRGB == wrongTypes.selectionRGB)
    #expect(wrongTypes.inactivePaneOpacity == 1)
  }

  /// A fade nobody can read through is not a signal, so the value is
  /// clamped rather than taken at its word.
  @Test func aFadeOutsideTheUsableRangeIsClamped() throws {
    func opacity(_ value: String) throws -> Double {
      try decode(
        Theme.self,
        #"""
        { "id": "x", "name": "X", "isDark": true, "background": "#000000",
          "foreground": "#ffffff", "cursor": "#ffffff", "selectionBackground": "#2f4f7a",
          "inactivePaneOpacity": \#(value),
          "ansi": ["#000"\#(String(repeating: ",\"#000\"", count: 15))] }
        """#
      ).inactivePaneOpacity
    }
    #expect(try opacity("0") == Theme.minimumInactivePaneOpacity)
    #expect(try opacity("-4") == Theme.minimumInactivePaneOpacity)
    #expect(try opacity("2") == 1)
    #expect(try opacity("0.6") == 0.6)
  }

  /// A group written by a build that had neither field, and one whose width
  /// is a number nothing can be laid out in.
  @Test func aTabGroupWithoutAWidthOrAnActiveTabStillLoads() throws {
    let bare = try decode(
      TabGroup.self, #"{ "id": "\#(UUID())", "worktreeID": "/repos/demo" }"#)
    #expect(bare.weight == 1)
    #expect(bare.activeTabID == nil)

    let zero = try decode(
      TabGroup.self, #"{ "id": "\#(UUID())", "worktreeID": "/repos/demo", "weight": 0 }"#)
    #expect(zero.weight == 1, "a column of no width would draw nothing")
  }

  /// Every tab of a state file written before columns existed. The tabs and
  /// their panes must survive; the column is `repairReferences`' to supply.
  @Test func aTabWithoutAColumnDecodesAsUnassigned() throws {
    let session = UUID()
    let tab = try decode(
      TerminalTab.self,
      #"""
      { "id": "\#(UUID())", "worktreeID": "/repos/demo", "focusedSessionID": "\#(session)",
        "root": { "terminal": { "_0": "\#(session)" } } }
      """#)
    #expect(tab.groupID == TabGroup.unassigned)
    #expect(tab.sessionIDs == [session])
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
    #expect(workspace.notifications == .off, "no state banners until asked for")
    #expect(workspace.preferredAgentID == nil)
    #expect(workspace.customAgentCommand == "")
    #expect(!workspace.autoStartAgent, "off until asked for")
    #expect(!workspace.autoStartAgentOnCreate, "off until asked for")
  }

  @Test func aWorkspaceFromBeforeAutoStartWasSplitSaysTheSameAboutCreation() throws {
    let on = try decode(Workspace.self, #"{ "autoStartAgent": true }"#)
    #expect(on.autoStartAgentOnCreate, "what the one setting used to mean")
    let split = try decode(
      Workspace.self, #"{ "autoStartAgent": true, "autoStartAgentOnCreate": false }"#)
    #expect(split.autoStartAgent && !split.autoStartAgentOnCreate)
  }

  @Test func aNotificationPreferenceThisBuildDoesNotKnowFallsBack() throws {
    let workspace = try decode(
      Workspace.self,
      #"{ "notifications": "whisper", "preferredAgentID": "future-agent", "projects": [ { "path": "file:///repos/demo/" } ] }"#
    )
    #expect(workspace.notifications == .off)
    #expect(workspace.preferredAgentID == "future-agent", "an unknown agent id is kept as text")
    #expect(workspace.projects.count == 1)

    let partial = try decode(
      NotificationPreference.self, #"{ "done": true, "whisper": true, "error": "yes" }"#)
    #expect(
      partial == NotificationPreference(done: true),
      "a state this build has not got is not one, and a bad value costs its own toggle")
  }

  @Test func aWorkspaceFromBeforeTheNotificationTogglesKeepsWhatThePickerSaid() throws {
    let attention = try decode(Workspace.self, #"{ "notifications": "attentionOnly" }"#)
    #expect(attention.notifications == NotificationPreference(attention: true))
    let everything = try decode(Workspace.self, #"{ "notifications": "attentionAndDone" }"#)
    #expect(
      everything.notifications == NotificationPreference(attention: true, error: true, done: true),
      "the picker's last rung was all three")
    let off = try decode(Workspace.self, #"{ "notifications": "off" }"#)
    #expect(off.notifications == .off)
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

  @Test func projectSettingsSplitAutoStartAndOpenOnCreateFollowTheGlobalUntilOverridden() throws {
    let empty = try decode(ProjectSettings.self, "{}")
    #expect(empty.autoStartAgentOnCreate == nil && empty.opensTerminalOnCreate == nil)
    #expect(empty.opensTerminalOnSelect == nil)
    // The one override state files had before the split stays the tab-open
    // one; creation follows the global, which carries the old value.
    let old = try decode(ProjectSettings.self, #"{ "autoStartAgent": true }"#)
    #expect(old.autoStartAgentOnCreate == nil, "follows the global")
    let split = try decode(
      ProjectSettings.self, #"{ "autoStartAgent": true, "autoStartAgentOnCreate": false }"#)
    #expect(split.autoStartAgentOnCreate == false)
    #expect(
      try decode(ProjectSettings.self, #"{ "opensTerminalOnCreate": false }"#)
        .opensTerminalOnCreate == false)
    #expect(
      try decode(ProjectSettings.self, #"{ "opensTerminalOnSelect": false }"#)
        .opensTerminalOnSelect == false)
  }

  /// One override on and its neighbour following the global is a state the
  /// forms can produce, so it has to survive being written and read back:
  /// a nil override is an absent key, and seeding one field from another
  /// would read that absence as an override next launch.
  @Test func anOverriddenSettingBesideOneFollowingTheGlobalSurvivesARoundTrip() throws {
    var settings = ProjectSettings()
    settings.autoStartAgent = true
    settings.opensTerminalOnCreate = false
    let json = try JSONEncoder().encode(settings)
    let back = try JSONDecoder().decode(ProjectSettings.self, from: json)
    #expect(back.autoStartAgent == true)
    #expect(back.autoStartAgentOnCreate == nil, "still following the global")
    #expect(back.opensTerminalOnCreate == false)
  }

  @Test func projectSettingsWithoutTheNewerFieldsGetTheirDefaults() throws {
    let settings = try decode(ProjectSettings.self, #"{ "postCreateHook": "npm install" }"#)
    #expect(settings.preCreateHook == "" && settings.preDeleteHook == "")
    #expect(
      settings.linkedPaths == "" && settings.copiedPaths == "",
      "a new worktree is linked to nothing and given nothing")
    #expect(settings.postCreateHook == "npm install")
    #expect(settings.defaultShell == nil, "follows the global shell")
    #expect(settings.iconGlyph == nil && settings.iconTint == nil, "the folder, untinted")
    #expect(settings.defaultBranch == nil, "detected rather than named")

    let shell = try decode(ProjectSettings.self, #"{ "defaultShell": "" }"#)
    #expect(shell.defaultShell == nil, "empty is noise where `login` is how none is spelled")
    let login = try decode(ProjectSettings.self, #"{ "defaultShell": "login" }"#)
    #expect(login.defaultShell == ShellCatalogue.loginShellID)

    // Kept, not coerced, for all three worktree fields: blank is the only
    // way one of them says "none" — the built-in directory, no prefix, or
    // detect — over what the global or the repository's file says. Every
    // reader trims, so `""` still means the built-in and still detects.
    let blank = try decode(
      ProjectSettings.self,
      #"{ "worktreeDirectory": "", "branchPrefix": "", "defaultBranch": "" }"#)
    #expect(blank.worktreeDirectory == "")
    #expect(blank.branchPrefix == "")
    #expect(blank.defaultBranch == "")
    #expect(
      try decode(ProjectSettings.self, #"{ "defaultBranch": "develop" }"#).defaultBranch
        == "develop")

    // The absent key is what "follow the global" is written as, and it must
    // stay distinguishable from the blank above across a round trip.
    var pinned = ProjectSettings()
    pinned.branchPrefix = ""
    let restored = try JSONDecoder().decode(
      ProjectSettings.self, from: try JSONEncoder().encode(pinned))
    #expect(restored.branchPrefix == "", "pinned to no prefix, not following the global")
    #expect(restored.worktreeDirectory == nil, "untouched, so still following the global")
  }

  @Test func anIconTintOutsideTheThemeOrOfTheWrongTypeIsDropped() throws {
    #expect(try decode(ProjectSettings.self, #"{ "iconTint": 16 }"#).iconTint == nil)
    #expect(try decode(ProjectSettings.self, #"{ "iconTint": -1 }"#).iconTint == nil)
    #expect(try decode(ProjectSettings.self, #"{ "iconTint": "red" }"#).iconTint == nil)
    #expect(try decode(ProjectSettings.self, #"{ "iconTint": 3 }"#).iconTint == 3)
    #expect(
      try decode(ProjectSettings.self, #"{ "iconGlyph": "🚀", "iconTint": 3 }"#).iconGlyph == "🚀",
      "kept as written, nothing on disk being rewritten behind the user; that it counts as no choice is ProjectIcon.symbolName's to say"
    )
  }

  @Test func aWorkspaceWithoutShellEditorOrSelectionFieldsGetsTheDefaults() throws {
    let workspace = try decode(Workspace.self, #"{ "projects": [] }"#)
    #expect(workspace.defaultShell == nil, "$SHELL")
    #expect(workspace.customShellPath == "")
    #expect(workspace.preferredEditorID == nil)
    #expect(workspace.customEditorCommand == "")
    #expect(workspace.opensTerminalOnSelect, "on until turned off")
    #expect(workspace.opensTerminalOnCreate, "on until turned off")

    let chosen = try decode(
      Workspace.self,
      #"{ "defaultShell": "/opt/homebrew/bin/fish", "preferredEditorID": "future-editor", "opensTerminalOnSelect": false, "opensTerminalOnCreate": false }"#
    )
    #expect(chosen.defaultShell == "/opt/homebrew/bin/fish")
    #expect(chosen.preferredEditorID == "future-editor", "an unknown editor id is kept as text")
    #expect(!chosen.opensTerminalOnSelect)
    #expect(!chosen.opensTerminalOnCreate)
  }

  /// A create used to open its terminal through the selection that follows
  /// it, so someone who turned selecting off is not handed one now.
  @Test func aWorkspaceFromBeforeOpenOnCreateWasSplitKeepsWhatSelectingSaid() throws {
    let looksFirst = try decode(Workspace.self, #"{ "opensTerminalOnSelect": false }"#)
    #expect(!looksFirst.opensTerminalOnCreate, "no terminal on create either, as before")
    let split = try decode(
      Workspace.self, #"{ "opensTerminalOnSelect": false, "opensTerminalOnCreate": true }"#)
    #expect(split.opensTerminalOnCreate, "once said separately, it is its own setting")
  }

  @Test func aWorkspaceWithoutTheRemovalFieldsAsksAndKeepsTheBranch() throws {
    let workspace = try decode(Workspace.self, #"{ "projects": [] }"#)
    #expect(workspace.confirmsWorktreeRemoval, "asks until told not to")
    #expect(!workspace.deletesBranchWithWorktree, "the branch stays until told otherwise")

    let chosen = try decode(
      Workspace.self,
      #"{ "confirmsWorktreeRemoval": false, "deletesBranchWithWorktree": true, "defaultShell": "custom", "customShellPath": "/opt/nu" }"#
    )
    #expect(!chosen.confirmsWorktreeRemoval && chosen.deletesBranchWithWorktree)
    #expect(chosen.defaultShell == ShellCatalogue.customID && chosen.customShellPath == "/opt/nu")
  }

  @Test func aWorkspaceWithoutTheListingFieldsSortsByNameWithNothingLifted() throws {
    let workspace = try decode(Workspace.self, #"{ "projects": [] }"#)
    #expect(workspace.worktreeSortOrder == .alphabetical)
    #expect(!workspace.showsActiveWorktreesFirst, "off until asked for")

    let chosen = try decode(
      Workspace.self,
      #"{ "worktreeSortOrder": "createdNewestFirst", "showsActiveWorktreesFirst": true }"#)
    #expect(chosen.worktreeSortOrder == .createdNewestFirst && chosen.showsActiveWorktreesFirst)
  }

  /// An order a newer build named costs the sidebar nothing: it reads as
  /// the default rather than failing the file.
  @Test func anUnknownSortOrderFallsBackRatherThanLosingTheWorkspace() throws {
    let workspace = try decode(
      Workspace.self, #"{ "projects": [], "worktreeSortOrder": "byMergeState" }"#)
    #expect(workspace.worktreeSortOrder == .alphabetical)

    let settings = try decode(ProjectSettings.self, #"{ "worktreeSortOrder": "byMergeState" }"#)
    #expect(settings.worktreeSortOrder == nil, "follows the global instead")
  }

  @Test func projectSettingsWithoutTheListingFieldsFollowTheGlobal() throws {
    let empty = try decode(ProjectSettings.self, "{}")
    #expect(empty.worktreeSortOrder == nil && empty.showsActiveWorktreesFirst == nil)
    let chosen = try decode(
      ProjectSettings.self,
      #"{ "worktreeSortOrder": "createdOldestFirst", "showsActiveWorktreesFirst": false }"#)
    #expect(chosen.worktreeSortOrder == .createdOldestFirst)
    #expect(chosen.showsActiveWorktreesFirst == false, "an override that says off")
  }

  /// The date is read off the filesystem at discovery, so state written
  /// before the field existed simply has none.
  @Test func aWorktreeWithoutACreationDateHasNone() throws {
    let worktree = try decode(
      Worktree.self,
      #"{ "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "abc" }"#)
    #expect(worktree.createdAt == nil)

    let dated = try decode(
      Worktree.self,
      #"{ "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "abc", "createdAt": 1000 }"#
    )
    #expect(dated.createdAt == Date(timeIntervalSinceReferenceDate: 1000))
  }

  /// A date in a shape this build does not read costs the date, not the
  /// worktree. Worktrees decode lossily, so throwing would drop the row and
  /// the tabs saved under it, and one odd entry must not take its
  /// neighbours with it either.
  @Test func aWorktreeWithAnUnreadableDateKeepsEverythingElse() throws {
    let odd = try decode(
      Worktree.self,
      #"""
      { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "abc",
        "createdAt": "2026-09-08T00:00:00Z" }
      """#)
    #expect(odd.createdAt == nil)
    #expect(odd.id == "/repos/demo", "the worktree itself still loads")

    let workspace = try decode(
      Workspace.self,
      #"""
      { "projects": [ { "path": "file:///repos/demo/" } ],
        "worktrees": [
          { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a",
            "createdAt": "nonsense" },
          { "path": "file:///repos/demo-feat/", "projectID": "/repos/demo", "head": "b",
            "createdAt": 1000 }
        ] }
      """#)
    #expect(workspace.worktrees.count == 2)
    #expect(workspace.worktrees[0].createdAt == nil)
    #expect(workspace.worktrees[1].createdAt == Date(timeIntervalSinceReferenceDate: 1000))
  }

  @Test func aProjectsOldRemovalFlagIsIgnoredNowThatTheSettingIsGlobal() throws {
    let settings = try decode(ProjectSettings.self, #"{ "confirmsWorktreeRemoval": false }"#)
    #expect(settings == ProjectSettings())
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
    var group = TabGroup(worktreeID: worktree.id)
    let tab = TerminalTab(worktreeID: worktree.id, groupID: group.id, session: session.id)
    group.activeTabID = tab.id
    workspace.projects = [project]
    workspace.worktrees = [worktree]
    workspace.sessions = [session]
    workspace.tabs = [tab]
    workspace.tabGroups = [group]
    workspace.focusedGroupByWorktree = [worktree.id: group.id]

    let json = try JSONEncoder().encode(workspace)
    #expect(try JSONDecoder().decode(Workspace.self, from: json) == workspace)
  }
}

/// The fields added for bare repositories, the hook timeout and the shared
/// settings file.
@Suite
struct NewerFieldDefaultsTests {
  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
  }

  @Test func aWorktreeWithoutTheBareFlagIsNotBare() throws {
    let worktree = try decode(
      Worktree.self, #"{ "path": "file:///repos/demo/", "projectID": "/repos/demo" }"#)
    #expect(!worktree.isBare)
    let bare = try decode(
      Worktree.self,
      #"{ "path": "file:///repos/demo.git/", "projectID": "/repos/demo.git", "isBare": true }"#)
    #expect(bare.isBare && !bare.isDetached)
    #expect(bare.name == "demo.git", "a bare entry has no branch and no HEAD to name it by")
  }

  @Test func aWorkspaceWithoutAHookTimeoutGetsAMinute() throws {
    let workspace = try decode(Workspace.self, #"{ "projects": [] }"#)
    #expect(workspace.hookTimeoutSeconds == 60)
    #expect(workspace.hookTimeout == .seconds(60))
    let unlimited = try decode(Workspace.self, #"{ "hookTimeoutSeconds": 0 }"#)
    #expect(unlimited.hookTimeout == nil)
  }

  @Test func aWorkspaceWithoutCustomWorktreeNamesHasNone() throws {
    #expect(try decode(Workspace.self, #"{ "projects": [] }"#).worktreeNames.isEmpty)
    let named = try decode(
      Workspace.self, #"{ "worktreeNames": { "/repos/demo": "Checkout flow" } }"#)
    #expect(named.worktreeNames == ["/repos/demo": "Checkout flow"])
  }

  @Test func projectSettingsWithoutADecisionHaveNoneAndABrokenOneCostsOnlyItself() throws {
    let digest = FileDigest.sha256(of: Data(#"{ "postCreateHook": "npm ci" }"#.utf8))
    #expect(try decode(ProjectSettings.self, "{}").sharedHooks.isEmpty)
    let decided = try decode(
      ProjectSettings.self, #"{ "sharedHooks": [{ "digest": "\#(digest)", "trusted": true }] }"#)
    #expect(decided.sharedHooks == [SharedHooksDecision(digest: digest, trusted: true)])
    let broken = try decode(
      ProjectSettings.self, #"{ "sharedHooks": "yes", "branchPrefix": "k/" }"#)
    #expect(broken.sharedHooks.isEmpty && broken.branchPrefix == "k/")
    let oneBrokenAnswer = try decode(
      ProjectSettings.self,
      #"""
      { "sharedHooks": [{ "digest": "\#(digest)" },
                        { "digest": "beef", "trusted": false }], "branchPrefix": "k/" }
      """#)
    #expect(
      oneBrokenAnswer.sharedHooks == [SharedHooksDecision(digest: "beef", trusted: false)],
      "an answer that will not decode costs that answer, not the others or the project")
    #expect(oneBrokenAnswer.branchPrefix == "k/")

    // And what is written comes back, so an answer survives a save.
    let two = ProjectSettings(
      sharedHooks: [
        SharedHooksDecision(digest: digest, trusted: true),
        SharedHooksDecision(digest: "beef", trusted: false),
      ])
    let written = try JSONDecoder().decode(
      ProjectSettings.self, from: try JSONEncoder().encode(two))
    #expect(written.sharedHooks == two.sharedHooks)
  }

  /// A build before the answers were held against the file's digest stored
  /// the hook text it was answered about, which no digest can be had from.
  /// Such an answer is dropped and the hooks are asked about once more.
  @Test func aDecisionStoredAgainstTheHookTextIsDroppedRatherThanTrusted() throws {
    let legacy = try decode(
      ProjectSettings.self,
      #"{ "sharedHooks": { "hooks": "post-create:\nnpm ci", "trusted": true }, "branchPrefix": "k/" }"#
    )
    #expect(legacy.sharedHooks.isEmpty && legacy.branchPrefix == "k/")
  }
}
