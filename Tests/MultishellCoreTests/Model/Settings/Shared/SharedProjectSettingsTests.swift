import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct SharedProjectSettingsTests {
  @Test func everyFieldIsOptionalAndAWrongTypeCostsThatFieldOnly() throws {
    let shared = try decodeJSON(
      SharedProjectSettings.self,
      #"{ "branchPrefix": "team/", "iconTint": "blue", "postCreateHook": ["npm"], "iconGlyph": "🚀" }"#,
    )
    #expect(shared.branchPrefix == "team/")
    #expect(shared.iconTint == nil && shared.postCreateHook == nil)
    #expect(shared.iconGlyph == "🚀")
    #expect(try decodeJSON(SharedProjectSettings.self, "{}") == SharedProjectSettings())
    #expect(throws: DecodingError.self) { try decodeJSON(SharedProjectSettings.self, "[1, 2]") }
  }

  /// A blank hook is not a hook to be trusted, and a blank file list links
  /// nothing, so for those blank and absent come to the same thing.
  @Test func blankStringsReadAsAbsentWhereNoneAndNoOpinionAgree() throws {
    let shared = try decodeJSON(
      SharedProjectSettings.self,
      #"{ "preCreateHook": "", "postCreateHook": "  ", "linkedPaths": "", "iconGlyph": "" }"#,
    )
    #expect(shared.preCreateHook == nil && shared.postCreateHook == nil)
    #expect(shared.linkedPaths == nil && shared.iconGlyph == nil)
    #expect(!shared.asksForTrust, "or the trust question would ask about an empty script")
  }

  /// The three worktree fields are the exception: blank is the only way they
  /// say "none", so a file that says it must be able to.
  @Test func aBlankWorktreeFieldIsAnOpinionAndNotAnAbsence() throws {
    let shared = try decodeJSON(
      SharedProjectSettings.self,
      #"{ "worktreeDirectory": "  ", "branchPrefix": "", "defaultBranch": "" }"#,
    )
    #expect(shared.worktreeDirectory == "  ")
    #expect(shared.branchPrefix == "")
    #expect(shared.defaultBranch == "")

    let layered = ProjectSettings().layered(over: shared)
    let defaults = WorktreeSettings.globalDefaults
    #expect(
      layered.effectiveWorktreeSettings(defaults: defaults).branchPrefix == "",
      "the file's no-prefix beats the reader's global",
    )
  }

  @Test func aMissingFileLoadsAsNoneAndABrokenOneThrows() throws {
    let root = try Scratch.directory("shared")
    defer { Scratch.remove(root) }

    #expect(try SharedProjectSettings.load(from: root) == nil)
    try #"{ "branchPrefix": "team/" }"#.write(
      to: SharedProjectSettings.file(in: root),
      atomically: true,
      encoding: .utf8,
    )
    let loaded = try #require(try SharedProjectSettings.load(from: root))
    #expect(loaded.branchPrefix == "team/")
    #expect(
      loaded.digest
        == FileDigest.sha256(of: try Data(contentsOf: SharedProjectSettings.file(in: root))),
      "the digest is of the file's bytes, and is what a hook decision is held against",
    )
    try "not json".write(
      to: SharedProjectSettings.file(in: root),
      atomically: true,
      encoding: .utf8,
    )
    #expect(throws: (any Error).self) { try SharedProjectSettings.load(from: root) }
  }

  /// An order a newer build named, or a typo someone committed, must not
  /// cost the rest of the file or override the user's own choice.
  @Test func anOrderTheBuildDoesNotKnowCostsThatKeyOnly() throws {
    let shared = try decodeJSON(
      SharedProjectSettings.self,
      #"{ "worktreeSortOrder": "byMergeState", "branchPrefix": "team/" }"#,
    )
    #expect(shared.worktreeSortOrder == nil)
    #expect(shared.branchPrefix == "team/")
    #expect(ProjectSettings().layered(over: shared).worktreeSortOrder == nil, "follows the global")

    let wrongType = try decodeJSON(SharedProjectSettings.self, #"{ "worktreeSortOrder": 3 }"#)
    #expect(wrongType.worktreeSortOrder == nil)
    let wrongFlag = try decodeJSON(
      SharedProjectSettings.self,
      #"{ "showsActiveWorktreesFirst": "yes", "worktreeSortOrder": "createdOldestFirst" }"#,
    )
    #expect(wrongFlag.showsActiveWorktreesFirst == nil)
    #expect(wrongFlag.worktreeSortOrder == .createdOldestFirst, "the good key survives")
  }

  @Test func aFlagOfTheWrongTypeCostsThatFlagOnly() throws {
    let shared = try decodeJSON(
      SharedProjectSettings.self,
      #"{ "autoStartAgent": "yes", "opensTerminalOnCreate": false }"#,
    )
    #expect(shared.autoStartsAgent == nil)
    #expect(shared.opensTerminalOnCreate == false)
  }

  /// Export writes the whole file back, so a key or value a teammate's newer build committed goes
  /// back as it was.
  @Test func exportKeepsTheKeysThisBuildCannotRead() throws {
    let root = try Scratch.directory("shared")
    defer { Scratch.remove(root) }
    let file = SharedProjectSettings.file(in: root)
    try #"""
    { "$schema": "https://example.test/multishell.json",
      "branchPrefix": "team/",
      "worktreeSortOrder": "byMergeState",
      "autoStartAgent": "yes",
      "iconTint": "blue",
      "reviewers": { "default": ["meg", 3, true, null, 1.5] } }
    """#.write(to: file, atomically: true, encoding: .utf8)
    let existing = try #require(try SharedProjectSettings.load(from: root))
    #expect(existing.worktreeSortOrder == nil && existing.iconTint == nil)

    let inForce = ProjectSettings(iconTint: 2).layered(over: existing)
    let written = try SharedProjectSettings(exporting: inForce).carryingOver(from: existing).write(
      to: root
    )

    let json = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
    )
    #expect(json["$schema"] as? String == "https://example.test/multishell.json")
    #expect(json["branchPrefix"] as? String == "team/", "read, so in force, so exported")
    #expect(json["worktreeSortOrder"] as? String == "byMergeState", "an order a newer build named")
    #expect(json["autoStartAgent"] as? String == "yes", "a value this build could not read")
    #expect(json["iconTint"] as? Int == 2, "the export's value wins where it has one")
    let reviewers = json["reviewers"] as? [String: Any]
    #expect(reviewers?["default"] as? NSArray == ["meg", 3, true, NSNull(), 1.5] as NSArray)
    let text = try String(contentsOf: file, encoding: .utf8)
    #expect(text.contains("true") && text.contains("null"), "a bool stays a bool")
    #expect(
      try SharedProjectSettings.load(from: root) == written,
      "what write returns is the file",
    )
  }

  @Test func aWhitespaceOnlyHookOfTheUsersTurnsTheFilesOff() throws {
    let shared = try writtenAndReadBack(SharedProjectSettings(postCreateHook: "npm ci"))
    var settings = ProjectSettings(postCreateHook: " ")
    settings.trustDecisions = [TrustDecision(digest: try #require(shared.digest), isTrusted: true)]
    let optedOut = settings.layered(over: shared)
    #expect(optedOut.postCreateHook == " ", "kept as the user's none, not replaced")
  }
}
