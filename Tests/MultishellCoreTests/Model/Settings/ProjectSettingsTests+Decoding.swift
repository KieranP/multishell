import Foundation
import Testing

@testable import MultishellCore

extension ProjectSettingsTests {
  @Test func projectSettingsKeepAnUnknownAgentIdAndReadEmptyAsNoOverride() throws {
    let unknown = try decodeJSON(ProjectSettings.self, #"{ "preferredAgentID": "future-agent" }"#)
    #expect(unknown.preferredAgentID == "future-agent")
    let empty = try decodeJSON(ProjectSettings.self, #"{ "preferredAgentID": "" }"#)
    #expect(empty.preferredAgentID == nil)
    #expect(try decodeJSON(ProjectSettings.self, "{}").preferredAgentID == nil)
    #expect(try decodeJSON(ProjectSettings.self, "{}").autoStartAgent == nil, "follows the global")
    #expect(
      try decodeJSON(ProjectSettings.self, #"{ "autoStartAgent": false }"#).autoStartAgent == false)
  }

  @Test func projectSettingsSplitAutoStartAndOpenOnCreateFollowTheGlobalUntilOverridden() throws {
    let empty = try decodeJSON(ProjectSettings.self, "{}")
    #expect(empty.autoStartAgentOnCreate == nil && empty.opensTerminalOnCreate == nil)
    #expect(empty.opensTerminalOnSelect == nil)
    // The one override state files had before the split stays the tab-open
    // one; creation follows the global, which carries the old value.
    let old = try decodeJSON(ProjectSettings.self, #"{ "autoStartAgent": true }"#)
    #expect(old.autoStartAgentOnCreate == nil, "follows the global")
    let split = try decodeJSON(
      ProjectSettings.self, #"{ "autoStartAgent": true, "autoStartAgentOnCreate": false }"#)
    #expect(split.autoStartAgentOnCreate == false)
    #expect(
      try decodeJSON(ProjectSettings.self, #"{ "opensTerminalOnCreate": false }"#)
        .opensTerminalOnCreate == false)
    #expect(
      try decodeJSON(ProjectSettings.self, #"{ "opensTerminalOnSelect": false }"#)
        .opensTerminalOnSelect == false)
  }

  /// A nil override is an absent key, so seeding one field from another
  /// would read that absence as an override on the next launch.
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
    let settings = try decodeJSON(ProjectSettings.self, #"{ "postCreateHook": "npm install" }"#)
    #expect(settings.preCreateHook == "" && settings.preDeleteHook == "")
    #expect(
      settings.linkedPaths == "" && settings.copiedPaths == "",
      "a new worktree is linked to nothing and given nothing")
    #expect(settings.postCreateHook == "npm install")
    #expect(settings.preferredShellID == nil, "follows the global shell")
    #expect(settings.iconGlyph == nil && settings.iconTint == nil, "the folder, untinted")
    #expect(settings.defaultBranch == nil, "detected rather than named")

    let shell = try decodeJSON(ProjectSettings.self, #"{ "defaultShell": "" }"#)
    #expect(shell.preferredShellID == nil, "empty is noise where `login` is how none is spelled")
    let login = try decodeJSON(ProjectSettings.self, #"{ "defaultShell": "login" }"#)
    #expect(login.preferredShellID == ShellCatalogue.loginShellID)

    // Kept, not coerced: blank is the only way these three say "none" over
    // the global or the file. Every reader trims, so `""` still detects.
    let blank = try decodeJSON(
      ProjectSettings.self,
      #"{ "worktreeDirectory": "", "branchPrefix": "", "defaultBranch": "" }"#)
    #expect(blank.worktreeDirectory == "")
    #expect(blank.branchPrefix == "")
    #expect(blank.defaultBranch == "")
    #expect(
      try decodeJSON(ProjectSettings.self, #"{ "defaultBranch": "develop" }"#).defaultBranch
        == "develop")

    // The fourth field with no other spelling for none: blank runs the
    // agent bare under a global that passes flags.
    #expect(try decodeJSON(ProjectSettings.self, #"{ "agentFlags": "" }"#).agentFlags == "")
    #expect(
      try decodeJSON(ProjectSettings.self, #"{ "postCreateHook": "x" }"#).agentFlags == nil,
      "absent follows the global")

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
    #expect(try decodeJSON(ProjectSettings.self, #"{ "iconTint": 16 }"#).iconTint == nil)
    #expect(try decodeJSON(ProjectSettings.self, #"{ "iconTint": -1 }"#).iconTint == nil)
    #expect(try decodeJSON(ProjectSettings.self, #"{ "iconTint": "red" }"#).iconTint == nil)
    #expect(try decodeJSON(ProjectSettings.self, #"{ "iconTint": 3 }"#).iconTint == 3)
    #expect(
      try decodeJSON(ProjectSettings.self, #"{ "iconGlyph": "🚀", "iconTint": 3 }"#).iconGlyph
        == "🚀",
      "kept as written, nothing on disk being rewritten behind the user; that it counts as no choice is ProjectIcon.normalizedGlyph's to say"
    )
  }

  @Test func projectSettingsWithoutTheListingFieldsFollowTheGlobal() throws {
    let empty = try decodeJSON(ProjectSettings.self, "{}")
    #expect(empty.worktreeSortOrder == nil && empty.showsActiveWorktreesFirst == nil)
    let chosen = try decodeJSON(
      ProjectSettings.self,
      #"{ "worktreeSortOrder": "createdOldestFirst", "showsActiveWorktreesFirst": false }"#)
    #expect(chosen.worktreeSortOrder == .createdOldestFirst)
    #expect(chosen.showsActiveWorktreesFirst == false, "an override that says off")
  }

  @Test func aProjectsOldRemovalFlagIsIgnoredNowThatTheSettingIsGlobal() throws {
    let settings = try decodeJSON(ProjectSettings.self, #"{ "confirmsWorktreeRemoval": false }"#)
    #expect(settings == ProjectSettings())
  }

  @Test func projectSettingsWithoutADecisionHaveNoneAndABrokenOneCostsOnlyItself() throws {
    let digest = FileDigest.sha256(of: Data(#"{ "postCreateHook": "npm ci" }"#.utf8))
    #expect(try decodeJSON(ProjectSettings.self, "{}").trustDecisions.isEmpty)
    let decided = try decodeJSON(
      ProjectSettings.self, #"{ "sharedHooks": [{ "digest": "\#(digest)", "trusted": true }] }"#)
    #expect(
      decided.trustDecisions == [TrustDecision(digest: digest, trusted: true)])
    let broken = try decodeJSON(
      ProjectSettings.self, #"{ "sharedHooks": "yes", "branchPrefix": "k/" }"#)
    #expect(broken.trustDecisions.isEmpty && broken.branchPrefix == "k/")
    let oneBrokenAnswer = try decodeJSON(
      ProjectSettings.self,
      #"""
      { "sharedHooks": [{ "digest": "\#(digest)" },
                        { "digest": "beef", "trusted": false }], "branchPrefix": "k/" }
      """#)
    #expect(
      oneBrokenAnswer.trustDecisions == [
        TrustDecision(digest: "beef", trusted: false)
      ],
      "an answer that will not decode costs that answer, not the others or the project")
    #expect(oneBrokenAnswer.branchPrefix == "k/")

    // And what is written comes back, so an answer survives a save.
    let two = ProjectSettings(
      trustDecisions: [
        TrustDecision(digest: digest, trusted: true),
        TrustDecision(digest: "beef", trusted: false),
      ])
    let encoded = try JSONEncoder().encode(two)
    let written = try JSONDecoder().decode(ProjectSettings.self, from: encoded)
    #expect(written.trustDecisions == two.trustDecisions)
    let keys = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any]).keys
    #expect(keys.contains("sharedHooks"), "the key every answer already given is stored under")
  }

  /// An older build stored the hook text, which yields no digest, so such
  /// an answer is dropped and the hooks are asked about again.
  @Test func aDecisionStoredAgainstTheHookTextIsDroppedRatherThanTrusted() throws {
    let legacy = try decodeJSON(
      ProjectSettings.self,
      #"{ "sharedHooks": { "hooks": "post-create:\nnpm ci", "trusted": true }, "branchPrefix": "k/" }"#
    )
    #expect(legacy.trustDecisions.isEmpty && legacy.branchPrefix == "k/")
  }
}
