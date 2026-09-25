import Foundation
import Testing

@testable import MultishellCore

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
    #expect(try decode(ProjectSettings.self, "{}").sharedSettingsDecisions.isEmpty)
    let decided = try decode(
      ProjectSettings.self, #"{ "sharedHooks": [{ "digest": "\#(digest)", "trusted": true }] }"#)
    #expect(
      decided.sharedSettingsDecisions == [SharedSettingsDecision(digest: digest, trusted: true)])
    let broken = try decode(
      ProjectSettings.self, #"{ "sharedHooks": "yes", "branchPrefix": "k/" }"#)
    #expect(broken.sharedSettingsDecisions.isEmpty && broken.branchPrefix == "k/")
    let oneBrokenAnswer = try decode(
      ProjectSettings.self,
      #"""
      { "sharedHooks": [{ "digest": "\#(digest)" },
                        { "digest": "beef", "trusted": false }], "branchPrefix": "k/" }
      """#)
    #expect(
      oneBrokenAnswer.sharedSettingsDecisions == [
        SharedSettingsDecision(digest: "beef", trusted: false)
      ],
      "an answer that will not decode costs that answer, not the others or the project")
    #expect(oneBrokenAnswer.branchPrefix == "k/")

    // And what is written comes back, so an answer survives a save.
    let two = ProjectSettings(
      sharedSettingsDecisions: [
        SharedSettingsDecision(digest: digest, trusted: true),
        SharedSettingsDecision(digest: "beef", trusted: false),
      ])
    let encoded = try JSONEncoder().encode(two)
    let written = try JSONDecoder().decode(ProjectSettings.self, from: encoded)
    #expect(written.sharedSettingsDecisions == two.sharedSettingsDecisions)
    let keys = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any]).keys
    #expect(keys.contains("sharedHooks"), "the key every answer already given is stored under")
  }

  /// An older build stored the hook text, which yields no digest, so such
  /// an answer is dropped and the hooks are asked about again.
  @Test func aDecisionStoredAgainstTheHookTextIsDroppedRatherThanTrusted() throws {
    let legacy = try decode(
      ProjectSettings.self,
      #"{ "sharedHooks": { "hooks": "post-create:\nnpm ci", "trusted": true }, "branchPrefix": "k/" }"#
    )
    #expect(legacy.sharedSettingsDecisions.isEmpty && legacy.branchPrefix == "k/")
  }

  /// `decode(_:forKey:or:)` fills an absent key and still fails on a wrong
  /// type, which is what moves a state file aside as `.broken.json`.
  @Test func theStrictReadDefaultsWhatIsAbsentAndFailsOnWhatIsWrong() throws {
    #expect(try decode(Workspace.self, "{}").customShellPath == "")
    #expect(
      try decode(Workspace.self, #"{ "customShellPath": "/bin/fish" }"#)
        .customShellPath == "/bin/fish")
    #expect(throws: (any Error).self) {
      try decode(Workspace.self, #"{ "customShellPath": 7 }"#)
    }
  }

  /// A `decodeTolerantly` read takes the default for a value this build
  /// cannot read, and the rest of the file loads around it.
  @Test func theTolerantReadKeepsTheRestOfTheFile() throws {
    let order = try decode(
      Workspace.self, #"{ "worktreeSortOrder": 12, "customShellPath": "/bin/fish" }"#)
    #expect(order.worktreeSortOrder == WorktreeSortOrder.default)
    #expect(order.customShellPath == "/bin/fish")

    // The optional form, where absent is itself the answer.
    #expect(
      try decode(ProjectSettings.self, #"{ "worktreeSortOrder": 12 }"#)
        .worktreeSortOrder == nil)
  }
}
