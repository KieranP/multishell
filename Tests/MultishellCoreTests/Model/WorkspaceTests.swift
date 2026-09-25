import Foundation
import Testing

@testable import MultishellCore

struct WorkspaceTests {
  @Test func everyStoredFieldIsWrittenUnderItsOwnKey() throws {
    var workspace = Workspace()
    workspace.selectedWorktreeID = "/repos/demo"
    workspace.preferredAgentID = "codex"
    workspace.preferredShellID = "/bin/zsh"
    workspace.preferredEditorID = "zed"
    let fields = Mirror(reflecting: workspace).children.count
    let encoded = try JSONEncoder().encode(workspace)
    let keys = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any]).keys

    #expect(keys.count == fields, "a field missing from CodingKeys is silently never saved")
    #expect(keys.contains("defaultShell"), "the key every earlier state file used")
  }

  @Test func aKeyNoFieldAnswersToDoesNotFailTheFile() throws {
    // Written by a build whose settings this one does not have. Losing the
    // key is fine; losing every project is not.
    let workspace = try decodeJSON(
      Workspace.self,
      #"{ "retiredSetting": "holodeck", "projects": [ { "path": "file:///repos/demo/" } ] }"#)
    #expect(workspace.projects.map(\.name) == ["demo"])
  }

  @Test func aWorkspaceWithoutAgentOrNotificationFieldsGetsTheDefaults() throws {
    let workspace = try decodeJSON(Workspace.self, #"{ "projects": [] }"#)
    #expect(workspace.notifications == .off, "no state banners until asked for")
    #expect(workspace.preferredAgentID == nil)
    #expect(workspace.customAgentCommand == "")
    #expect(workspace.agentFlags.isEmpty, "no agent is given flags it was not asked to pass")
    #expect(!workspace.autoStartAgent, "off until asked for")
    #expect(!workspace.autoStartAgentOnCreate, "off until asked for")
  }

  @Test func aWorkspaceFromBeforeAutoStartWasSplitSaysTheSameAboutCreation() throws {
    let on = try decodeJSON(Workspace.self, #"{ "autoStartAgent": true }"#)
    #expect(on.autoStartAgentOnCreate, "what the one setting used to mean")
    let split = try decodeJSON(
      Workspace.self, #"{ "autoStartAgent": true, "autoStartAgentOnCreate": false }"#)
    #expect(split.autoStartAgent && !split.autoStartAgentOnCreate)
  }

  @Test func aWorkspaceFromBeforeTheNotificationTogglesKeepsWhatThePickerSaid() throws {
    let attention = try decodeJSON(Workspace.self, #"{ "notifications": "attentionOnly" }"#)
    #expect(attention.notifications == NotificationPreference(attention: true))
    let everything = try decodeJSON(Workspace.self, #"{ "notifications": "attentionAndDone" }"#)
    #expect(
      everything.notifications == NotificationPreference(attention: true, failed: true, done: true),
      "the picker's last rung was all three")
    let off = try decodeJSON(Workspace.self, #"{ "notifications": "off" }"#)
    #expect(off.notifications == .off)
  }

  @Test func aWorkspaceWithoutShellEditorOrSelectionFieldsGetsTheDefaults() throws {
    let workspace = try decodeJSON(Workspace.self, #"{ "projects": [] }"#)
    #expect(workspace.preferredShellID == nil, "$SHELL")
    #expect(workspace.customShellPath == "")
    #expect(workspace.preferredEditorID == nil)
    #expect(workspace.customEditorCommand == "")
    #expect(workspace.opensTerminalOnSelect, "on until turned off")
    #expect(workspace.opensTerminalOnCreate, "on until turned off")

    let chosen = try decodeJSON(
      Workspace.self,
      #"{ "defaultShell": "/opt/homebrew/bin/fish", "preferredEditorID": "future-editor", "opensTerminalOnSelect": false, "opensTerminalOnCreate": false }"#
    )
    #expect(chosen.preferredShellID == "/opt/homebrew/bin/fish")
    #expect(chosen.preferredEditorID == "future-editor", "an unknown editor id is kept as text")
    #expect(!chosen.opensTerminalOnSelect)
    #expect(!chosen.opensTerminalOnCreate)
  }

  /// A create used to open its terminal through the selection that follows
  /// it, so someone who turned selecting off is not handed one now.
  @Test func aWorkspaceFromBeforeOpenOnCreateWasSplitKeepsWhatSelectingSaid() throws {
    let looksFirst = try decodeJSON(Workspace.self, #"{ "opensTerminalOnSelect": false }"#)
    #expect(!looksFirst.opensTerminalOnCreate, "no terminal on create either, as before")
    let split = try decodeJSON(
      Workspace.self, #"{ "opensTerminalOnSelect": false, "opensTerminalOnCreate": true }"#)
    #expect(split.opensTerminalOnCreate, "once said separately, it is its own setting")
  }

  @Test func anUnreadableGitStatusIndicatorFallsBackToCountingEverything() throws {
    #expect(try decodeJSON(Workspace.self, #"{ "projects": [] }"#).gitStatusIndicator == .default)
    #expect(
      try decodeJSON(Workspace.self, #"{ "gitStatusIndicator": "stagedOnly" }"#).gitStatusIndicator
        == .stagedOnly)
    #expect(
      try decodeJSON(Workspace.self, #"{ "gitStatusIndicator": "whateverIsNext" }"#)
        .gitStatusIndicator
        == .default, "a kind a newer build named costs that value alone")
  }

  @Test func aWorkspaceWithoutTheRemovalFieldsAsksAndKeepsTheBranch() throws {
    let workspace = try decodeJSON(Workspace.self, #"{ "projects": [] }"#)
    #expect(workspace.confirmsWorktreeRemoval, "asks until told not to")
    #expect(!workspace.deletesBranchWithWorktree, "the branch stays until told otherwise")
    #expect(workspace.trashesRemovedWorktrees, "the Trash until told to delete")

    let chosen = try decodeJSON(
      Workspace.self,
      #"{ "confirmsWorktreeRemoval": false, "deletesBranchWithWorktree": true, "trashesRemovedWorktrees": false, "defaultShell": "custom", "customShellPath": "/opt/nu" }"#
    )
    #expect(!chosen.confirmsWorktreeRemoval && chosen.deletesBranchWithWorktree)
    #expect(!chosen.trashesRemovedWorktrees)
    #expect(
      chosen.preferredShellID == ShellCatalogue.customID && chosen.customShellPath == "/opt/nu")
  }

  @Test func aWorkspaceWithoutTheListingFieldsSortsByNameWithNothingLifted() throws {
    let workspace = try decodeJSON(Workspace.self, #"{ "projects": [] }"#)
    #expect(workspace.worktreeSortOrder == .alphabetical)
    #expect(!workspace.showsActiveWorktreesFirst, "off until asked for")

    let chosen = try decodeJSON(
      Workspace.self,
      #"{ "worktreeSortOrder": "createdNewestFirst", "showsActiveWorktreesFirst": true }"#)
    #expect(chosen.worktreeSortOrder == .createdNewestFirst && chosen.showsActiveWorktreesFirst)
  }

  /// An order a newer build named costs the sidebar nothing: it reads as
  /// the default rather than failing the file.
  @Test func anUnknownSortOrderFallsBackRatherThanLosingTheWorkspace() throws {
    let workspace = try decodeJSON(
      Workspace.self, #"{ "projects": [], "worktreeSortOrder": "byMergeState" }"#)
    #expect(workspace.worktreeSortOrder == .alphabetical)

    let settings = try decodeJSON(ProjectSettings.self, #"{ "worktreeSortOrder": "byMergeState" }"#)
    #expect(settings.worktreeSortOrder == nil, "follows the global instead")
  }

  @Test func aWorkspaceFromTheFirstBuildAndOneFromTodayBothLoad() throws {
    let today = Workspace()
    let roundTripped = try decodeJSON(
      Workspace.self, String(decoding: JSONEncoder().encode(today), as: UTF8.self))
    #expect(roundTripped == today)

    let ancient = try decodeJSON(Workspace.self, "{}")
    #expect(ancient == Workspace())
  }

  @Test func aWorkspaceWithoutAHookTimeoutGetsAMinute() throws {
    let workspace = try decodeJSON(Workspace.self, #"{ "projects": [] }"#)
    #expect(workspace.hookTimeoutSeconds == 60)
    #expect(workspace.hookTimeout == .seconds(60))
    let unlimited = try decodeJSON(Workspace.self, #"{ "hookTimeoutSeconds": 0 }"#)
    #expect(unlimited.hookTimeout == nil)
  }

  @Test func aWorkspaceWithoutCustomWorktreeNamesHasNone() throws {
    #expect(try decodeJSON(Workspace.self, #"{ "projects": [] }"#).worktreeNames.isEmpty)
    let named = try decodeJSON(
      Workspace.self, #"{ "worktreeNames": { "/repos/demo": "Checkout flow" } }"#)
    #expect(named.worktreeNames == ["/repos/demo": "Checkout flow"])
  }

  @Test func aSavedLayoutIsWrittenUnderTheTabGroupKeysAndComesBackExactly() throws {
    let (workspace, _) = soundWorkspace()

    let json = String(decoding: try JSONEncoder().encode(workspace), as: UTF8.self)
    #expect(json.contains("tabGroups"))
    #expect(json.contains("focusedGroupByWorktree"))
    #expect(!json.contains("activeTabByWorktree"), "the old key is read, never written")

    var reloaded = try JSONDecoder().decode(Workspace.self, from: Data(json.utf8))
    reloaded.repairReferences()
    #expect(reloaded == workspace, "a saved layout comes back exactly")
  }
}
