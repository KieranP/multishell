import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct SharedProjectSettingsTests {
  private func decode(_ json: String) throws -> SharedProjectSettings {
    try JSONDecoder().decode(SharedProjectSettings.self, from: Data(json.utf8))
  }

  /// `copiedPaths: .aws.json` would carry a gitignored secret into a worktree
  /// an agent reads, so the lists wait for the same yes the hooks do.
  @Test func aFileListFromTheRepositoryWaitsForTrustLikeAHook() throws {
    let shared = try writtenAndReadBack(
      SharedProjectSettings(linkedPaths: "node_modules", copiedPaths: ".aws.json"))

    #expect(shared.asksForTrust, "and so the question is asked")
    let untrusted = ProjectSettings().layered(over: shared)
    #expect(untrusted.linkedPaths.isEmpty && untrusted.copiedPaths.isEmpty)

    var settings = ProjectSettings()
    settings.recordTrustDecision(digest: try #require(shared.digest), trusted: true)
    let trusted = settings.layered(over: shared)
    #expect(trusted.linkedPaths == "node_modules" && trusted.copiedPaths == ".aws.json")
  }

  @Test func theQuestionShowsTheListsAlongsideTheHooks() throws {
    let shared = SharedProjectSettings(
      postCreateHook: "npm ci", linkedPaths: "node_modules", copiedPaths: ".env")
    let text = try #require(shared.trustCoveredText)

    #expect(text.contains("post-create:\nnpm ci"))
    #expect(text.contains("linked:\nnode_modules"))
    #expect(text.contains("copied:\n.env"))
  }

  @Test func aFileWithNeitherHooksNorListsIsNeverAskedAbout() throws {
    let shared = try writtenAndReadBack(
      SharedProjectSettings(branchPrefix: "team/", iconGlyph: "hammer"))
    #expect(!shared.asksForTrust)
    #expect(shared.trustCoveredText == nil)
    #expect(!ProjectSettings().needsTrustDecision(for: shared))
  }

  @Test func everyFieldIsOptionalAndAWrongTypeCostsThatFieldOnly() throws {
    let shared = try decode(
      #"{ "branchPrefix": "team/", "iconTint": "blue", "postCreateHook": ["npm"], "iconGlyph": "🚀" }"#
    )
    #expect(shared.branchPrefix == "team/")
    #expect(shared.iconTint == nil && shared.postCreateHook == nil)
    #expect(shared.iconGlyph == "🚀")
    #expect(try decode("{}") == SharedProjectSettings())
    #expect(throws: DecodingError.self) { try decode("[1, 2]") }
  }

  /// A blank hook is not a hook to be trusted, and a blank file list links
  /// nothing, so for those blank and absent come to the same thing.
  @Test func blankStringsReadAsAbsentWhereNoneAndNoOpinionAgree() throws {
    let shared = try decode(
      #"{ "preCreateHook": "", "postCreateHook": "  ", "linkedPaths": "", "iconGlyph": "" }"#)
    #expect(shared.preCreateHook == nil && shared.postCreateHook == nil)
    #expect(shared.linkedPaths == nil && shared.iconGlyph == nil)
    #expect(!shared.asksForTrust, "or the trust question would ask about an empty script")
  }

  /// The three worktree fields are the exception: blank is the only way they
  /// say "none", so a file that says it must be able to.
  @Test func aBlankWorktreeFieldIsAnOpinionAndNotAnAbsence() throws {
    let shared = try decode(
      #"{ "worktreeDirectory": "  ", "branchPrefix": "", "defaultBranch": "" }"#)
    #expect(shared.worktreeDirectory == "  ")
    #expect(shared.branchPrefix == "")
    #expect(shared.defaultBranch == "")

    let layered = ProjectSettings().layered(over: shared)
    let defaults = WorktreeSettings(worktreeDirectory: "/global/trees", branchPrefix: "team/")
    #expect(
      layered.effectiveWorktreeSettings(defaults: defaults).branchPrefix == "",
      "the file's no-prefix beats the reader's global")
  }

  @Test func theHooksTextNamesEachHookSoTheQuestionSaysWhichStageRunsWhat() {
    let one = SharedProjectSettings(postCreateHook: "npm ci")
    #expect(one.trustCoveredText == "post-create:\nnpm ci")
    let two = SharedProjectSettings(postCreateHook: "npm ci", preDeleteHook: "exit 1")
    #expect(two.trustCoveredText == "post-create:\nnpm ci\n\npre-delete:\nexit 1")
    #expect(one.trustCoveredText != two.trustCoveredText, "a hook added is shown")
    #expect(SharedProjectSettings(branchPrefix: "x/").trustCoveredText == nil)
  }

  @Test func theQuestionNamesEachFieldInTheCataloguesWords() throws {
    let shared = SharedProjectSettings(
      worktreeDirectory: ".trees", preCreateHook: "a", postCreateHook: "b", preDeleteHook: "c",
      postDeleteHook: "d", linkedPaths: "e", copiedPaths: "f")
    let names = try #require(shared.trustCoveredText).split(separator: "\n\n").map {
      String($0.prefix { $0 != ":" })
    }

    #expect(
      names == [
        t("shared-settings.worktree-directory"), t("shared-settings.pre-create"),
        t("shared-settings.post-create"), t("shared-settings.pre-delete"),
        t("shared-settings.post-delete"), t("shared-settings.linked"),
        t("shared-settings.copied"),
      ])
  }

  @Test func loadReturnsNilForARepositoryWithoutTheFileAndThrowsForABrokenOne() throws {
    let root = try Scratch.directory("shared")
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(try SharedProjectSettings.load(from: root) == nil)
    try #"{ "branchPrefix": "team/" }"#.write(
      to: SharedProjectSettings.file(in: root), atomically: true, encoding: .utf8)
    let loaded = try #require(try SharedProjectSettings.load(from: root))
    #expect(loaded.branchPrefix == "team/")
    #expect(
      loaded.digest
        == FileDigest.sha256(of: try Data(contentsOf: SharedProjectSettings.file(in: root))),
      "the digest is of the file's bytes, and is what a hook decision is held against")
    try "not json".write(
      to: SharedProjectSettings.file(in: root), atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try SharedProjectSettings.load(from: root) }
  }

  @Test func theUsersValuesWinAndTheFileFillsWhatTheyLeftBlank() throws {
    let shared = try writtenAndReadBack(
      SharedProjectSettings(
        worktreeDirectory: "../trees", branchPrefix: "team/", defaultBranch: "develop",
        postCreateHook: "npm ci", iconGlyph: "hammer", iconTint: 4))
    let blank = ProjectSettings().layered(over: shared)
    #expect(blank.branchPrefix == "team/", "naming a branch writes nothing")
    #expect(blank.defaultBranch == "develop", "a repository may name the branch it merges into")
    #expect(blank.iconGlyph == "hammer" && blank.iconTint == 4)
    #expect(blank.postCreateHook == "", "hooks wait for trust")
    #expect(blank.worktreeDirectory == nil, "and so does where a checkout lands")

    let own = ProjectSettings(
      branchPrefix: "me/", defaultBranch: "trunk", postCreateHook: "make", iconTint: 1,
      trustDecisions: [
        TrustDecision(digest: try #require(shared.digest), trusted: true)
      ]
    ).layered(over: shared)
    #expect(own.worktreeDirectory == "../trees", "left blank, so the file's")
    #expect(own.branchPrefix == "me/" && own.iconTint == 1)
    #expect(own.defaultBranch == "trunk", "the user's name stands over the file's")
    #expect(own.postCreateHook == "make", "the user's hook stands over the file's")

    #expect(
      ProjectSettings(branchPrefix: "me/").layered(over: nil)
        == ProjectSettings(branchPrefix: "me/"))
  }

  /// Unlike a hook this runs nothing the repository wrote, only the shell or agent the user
  /// chose, so it needs no trust decision.
  @Test func aRepositoryMaySayWhatItsWorktreesOpenAndTheUsersOwnAnswerWins() throws {
    let shared = try decode(
      #"{ "autoStartAgent": true, "autoStartAgentOnCreate": true, "opensTerminalOnSelect": false, "opensTerminalOnCreate": true }"#
    )
    #expect(shared.autoStartAgent == true && shared.autoStartAgentOnCreate == true)
    #expect(shared.opensTerminalOnSelect == false && shared.opensTerminalOnCreate == true)

    let blank = ProjectSettings().layered(over: shared)
    #expect(blank.autoStartAgent == true && blank.autoStartAgentOnCreate == true)
    #expect(blank.opensTerminalOnSelect == false && blank.opensTerminalOnCreate == true)

    let own = ProjectSettings(autoStartAgent: false, opensTerminalOnSelect: true)
      .layered(over: shared)
    #expect(own.autoStartAgent == false, "the user's off stands over the file's on")
    #expect(own.opensTerminalOnSelect == true)
    #expect(own.autoStartAgentOnCreate == true, "left alone, so the file's")

    let exported = SharedProjectSettings(exporting: blank)
    #expect(exported.autoStartAgentOnCreate == true && exported.opensTerminalOnSelect == false)
  }

  @Test func aGlyphNoBuildDrawsIsNotAChoiceAndDoesNotMaskTheRepositorys() throws {
    let shared = try decode(#"{ "iconGlyph": "server.rack", "iconTint": 4 }"#)

    let blank = ProjectSettings().layered(over: shared)
    #expect(blank.iconGlyph == "server.rack" && blank.iconTint == 4)

    let own = ProjectSettings(iconGlyph: "cylinder").layered(over: shared)
    #expect(own.iconGlyph == "cylinder", "the user's choice stands over the file's")

    let leftover = ProjectSettings(iconGlyph: "🚀").layered(over: shared)
    #expect(
      leftover.iconGlyph == "server.rack",
      "an emoji from a build that offered them is a gap, not a choice over the file")

    let fileEmoji = try decode(#"{ "iconGlyph": "🚀" }"#)
    #expect(ProjectSettings().layered(over: fileEmoji).iconGlyph == nil, "and neither way round")
  }

  @Test func theIconInForceIsAlwaysASymbolNameAndSurvivesARoundTrip() {
    let stored: [String?] = [
      nil, "", "   ", "folder", "hammer", "  hammer  ", "server.rack",
      "sparkle.magnifyingglass", "not.a.symbol", "🚀", " 🚀 ", "🚀 hammer",
    ]
    for own in stored {
      for file in stored {
        let settings = ProjectSettings(iconGlyph: own)
        for shared in [SharedProjectSettings(iconGlyph: file), nil] {
          let effective = settings.layered(over: shared)
          #expect(
            ProjectIcon.normalizedGlyph(effective.iconGlyph) == effective.iconGlyph,
            "own \(own ?? "nil"), file \(file ?? "nil"): not a symbol name")

          let exported = SharedProjectSettings(exporting: effective)
          #expect(
            ProjectSettings().layered(over: exported).iconGlyph == effective.iconGlyph,
            "own \(own ?? "nil"), file \(file ?? "nil"): changed by the round trip")
        }
      }
    }
  }

  @Test func aRepositoryMaySayWhatOrderItsWorktreesListInAndTheUsersOwnWins() throws {
    let shared = try decode(
      #"{ "worktreeSortOrder": "committedNewestFirst", "showsActiveWorktreesFirst": true }"#)
    #expect(shared.worktreeSortOrder == .committedNewestFirst)
    #expect(shared.showsActiveWorktreesFirst == true)

    let blank = ProjectSettings().layered(over: shared)
    #expect(blank.worktreeSortOrder == .committedNewestFirst, "the gap the user left")
    #expect(blank.showsActiveWorktreesFirst == true)

    let own = ProjectSettings(
      worktreeSortOrder: .alphabetical, showsActiveWorktreesFirst: false
    ).layered(over: shared)
    #expect(own.worktreeSortOrder == .alphabetical, "the user's choice stands over the file's")
    #expect(own.showsActiveWorktreesFirst == false)

    // What Export writes back out, so a round trip through the file keeps
    // the order the project is actually using.
    let exported = SharedProjectSettings(exporting: blank)
    #expect(exported.worktreeSortOrder == .committedNewestFirst)
    #expect(exported.showsActiveWorktreesFirst == true)
    let written = try decode(String(decoding: try JSONEncoder().encode(exported), as: UTF8.self))
    #expect(written == exported)
  }

  /// An order a newer build named, or a typo someone committed, must not
  /// cost the rest of the file or override the user's own choice.
  @Test func anOrderTheBuildDoesNotKnowCostsThatKeyOnly() throws {
    let shared = try decode(
      #"{ "worktreeSortOrder": "byMergeState", "branchPrefix": "team/" }"#)
    #expect(shared.worktreeSortOrder == nil)
    #expect(shared.branchPrefix == "team/")
    #expect(ProjectSettings().layered(over: shared).worktreeSortOrder == nil, "follows the global")

    let wrongType = try decode(#"{ "worktreeSortOrder": 3 }"#)
    #expect(wrongType.worktreeSortOrder == nil)
    let wrongFlag = try decode(
      #"{ "showsActiveWorktreesFirst": "yes", "worktreeSortOrder": "createdOldestFirst" }"#)
    #expect(wrongFlag.showsActiveWorktreesFirst == nil)
    #expect(wrongFlag.worktreeSortOrder == .createdOldestFirst, "the good key survives")
  }

  @Test func aFlagOfTheWrongTypeCostsThatFlagOnly() throws {
    let shared = try decode(#"{ "autoStartAgent": "yes", "opensTerminalOnCreate": false }"#)
    #expect(shared.autoStartAgent == nil)
    #expect(shared.opensTerminalOnCreate == false)
  }

  /// Where a checkout lands is the reader's disk too. Inside the repository
  /// is all it may name, and even that waits for the file to be trusted.
  @Test func aRepositorysWorktreeDirectoryWaitsToBeTrusted() throws {
    let shared = try writtenAndReadBack(SharedProjectSettings(worktreeDirectory: ".worktrees"))
    #expect(shared.asksForTrust)
    #expect(try #require(shared.trustCoveredText).contains("worktree directory:\n.worktrees"))

    let untrusted = ProjectSettings().layered(over: shared)
    #expect(untrusted.worktreeDirectory == nil, "the reader's own, so the global default")

    var settings = ProjectSettings()
    settings.recordTrustDecision(digest: try #require(shared.digest), trusted: true)
    #expect(settings.layered(over: shared).worktreeDirectory == ".worktrees")
  }

  /// A list waits for the same yes a hook does. The user's own list is
  /// theirs and wins whole, trusted or not.
  @Test func aRepositorysListOfWhatNewWorktreesAreGivenWaitsToBeTrusted() throws {
    let shared = try writtenAndReadBack(
      SharedProjectSettings(linkedPaths: "node_modules", copiedPaths: ".env\n.env.local"))
    #expect(shared.asksForTrust, "a list reads files, so it is asked about")

    let untrusted = ProjectSettings().layered(over: shared)
    #expect(untrusted.copiedPaths.isEmpty && untrusted.linkedPaths.isEmpty)

    var settings = ProjectSettings()
    settings.recordTrustDecision(digest: try #require(shared.digest), trusted: true)
    let trusted = settings.layered(over: shared)
    #expect(trusted.copiedPaths == ".env\n.env.local" && trusted.linkedPaths == "node_modules")

    var own = ProjectSettings(linkedPaths: "vendor", copiedPaths: ".env")
    own.recordTrustDecision(digest: try #require(shared.digest), trusted: true)
    #expect(own.layered(over: shared).copiedPaths == ".env", "the user's list wins whole")
    #expect(own.layered(over: shared).linkedPaths == "vendor")
  }

  /// Export writes the whole file back, so a key or value a teammate's newer build committed goes
  /// back as it was.
  @Test func exportKeepsTheKeysThisBuildCannotRead() throws {
    let root = try Scratch.directory("shared")
    defer { try? FileManager.default.removeItem(at: root) }
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
    let written = try SharedProjectSettings(exporting: inForce).keeping(from: existing).write(
      to: root)

    let json = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    #expect(json["$schema"] as? String == "https://example.test/multishell.json")
    #expect(json["branchPrefix"] as? String == "team/", "read, so in force, so exported")
    #expect(json["worktreeSortOrder"] as? String == "byMergeState", "an order a newer build named")
    #expect(json["autoStartAgent"] as? String == "yes", "a value this build could not read")
    #expect(json["iconTint"] as? Int == 2, "the export's value wins where it has one")
    let reviewers = json["reviewers"] as? [String: Any]
    #expect(reviewers?["default"] as? NSArray == ["meg", 3, true, NSNull(), 1.5] as NSArray)
    let text = try String(contentsOf: file, encoding: .utf8)
    #expect(text.contains("true") && text.contains("null"), "a bool stays a bool")
    #expect(try SharedProjectSettings.load(from: root) == written, "what write returns is the file")
  }

  @Test func aWhitespaceOnlyHookOfTheUsersTurnsTheFilesOff() throws {
    let shared = try writtenAndReadBack(SharedProjectSettings(postCreateHook: "npm ci"))
    let optedOut = ProjectSettings(
      postCreateHook: " ",
      trustDecisions: [
        TrustDecision(digest: try #require(shared.digest), trusted: true)
      ]
    ).layered(over: shared)
    #expect(optedOut.postCreateHook == " ", "kept as the user's none, not replaced")
  }
}
