import Foundation
import MultishellProcess
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelSharedSettingsTests {
  @Test func anEditorOpenedAsATabAsksAboutTheSharedSettingsAsSelectingDoes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings(#"{ "postCreateHook": "echo shared" }"#)
    await harness.model.refreshWorktrees(of: harness.project)
    harness.model.setPreferredEditor(EditorCatalogue.customID)
    harness.model.setCustomEditorCommand("my-editor {path}")

    harness.model.openInEditor(harness.model.workspace.worktrees(of: harness.project.id)[0])

    #expect(harness.model.pendingSharedSettingsTrust?.projectID == harness.project.id)
  }

  @Test func theRepositorysSettingsFileFillsTheGapsAndItsHooksWaitForTrust() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings(
      #"{ "branchPrefix": "team/", "worktreeDirectory": ".shared-trees", "postCreateHook": "echo shared > hook.txt", "iconGlyph": "hammer" }"#
    )

    await harness.model.refreshWorktrees(of: harness.project)

    #expect(
      harness.project.sharedSettingsSnapshot.asWritten?.branchPrefix
        == "team/"
    )
    #expect(harness.model.effectiveWorktreeSettings(for: harness.project).branchPrefix == "team/")
    #expect(harness.model.effectiveSettings(for: harness.project).iconGlyph == "hammer")
    #expect(
      harness.model.plannedPath(forBranch: "x", createsBranch: true, in: harness.project)?.path
        .hasSuffix(
          "/.shared-trees/team-x"
        ) == false,
      "where a checkout lands waits for trust, unlike the prefix and the icon",
    )
    #expect(
      harness.model.pendingSharedSettingsTrust == nil,
      "not asked until the user turns to it",
    )
    harness.model.select(harness.model.workspace.worktrees(of: harness.project.id)[0])
    let pending = try #require(harness.model.pendingSharedSettingsTrust)
    #expect(
      pending.projectID == harness.project.id && pending.trustCoveredText.contains("echo shared")
    )
    #expect(!harness.model.trustsSharedSettings(of: harness.project))

    harness.model.decideSharedSettingsTrustLater()
    await harness.model.createWorktree(
      branch: "a",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
    )
    #expect(harness.model.pendingSharedSettingsTrust == nil, "the sheet is still going away then")
    let a = try #require(harness.worktree(onBranch: "team/a"))
    #expect(harness.model.stageHandles.setupTask(of: a.id) == nil)
    #expect(!FileManager.default.fileExists(atPath: a.path.appendingPathComponent("hook.txt").path))

    harness.model.answerSharedSettingsTrust(pending, isTrusted: true)
    #expect(harness.model.pendingSharedSettingsTrust == nil)
    #expect(harness.model.trustsSharedSettings(of: harness.project))
    #expect(
      harness.model.plannedPath(forBranch: "x", createsBranch: true, in: harness.project)?.path
        .hasSuffix(
          "/.shared-trees/team-x"
        ) == true,
      "and once trusted the file's directory is the one used",
    )
    await harness.model.createWorktree(
      branch: "b",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
    )
    let b = try #require(harness.worktree(onBranch: "team/b"))
    await harness.model.stageHandles.setupTask(of: b.id)?.value
    #expect(FileManager.default.fileExists(atPath: b.path.appendingPathComponent("hook.txt").path))

    harness.model.setSettings(
      harness.project.settings.with { settings in
        settings.branchPrefix = "me/"
      },
      for: harness.project,
    )
    #expect(harness.model.effectiveWorktreeSettings(for: harness.project).branchPrefix == "me/")
    try harness.writeSharedSettings(#"{ "postCreateHook": "echo changed" }"#)
    await harness.model.refreshWorktrees(of: harness.project)
    #expect(!harness.model.trustsSharedSettings(of: harness.project))
    harness.model.select(harness.model.workspace.worktrees(of: harness.project.id)[0])
    #expect(
      harness.model.pendingSharedSettingsTrust?.trustCoveredText == "post-create:\necho changed"
    )
  }

  /// What a committed file names outside the checkout is dropped, and the
  /// reader's own settings stand; see Docs/design/settings.md.
  @Test func aSettingsFileCannotPlaceAWorktreeOrReadFilesOutsideTheCheckout() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let key = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".ssh/id_ed25519").path
    let json = """
      { "worktreeDirectory": "~/.claude/skills", \
      "linkedPaths": "\(key)\\nvendor", "copiedPaths": "../../.aws/credentials" }
      """
    try harness.writeSharedSettings(json)

    await harness.model.refreshWorktrees(of: harness.project)
    // Trusted, so what is dropped here is dropped for reaching out and not
    // for waiting on an answer.
    try harness.answerTrust(true)

    let effective = harness.model.effectiveSettings(for: harness.project)
    #expect(effective.worktreeDirectory == nil, "the reader's own directory stands")
    #expect(effective.linkedPaths == "vendor", "only the entry reaching out is dropped")
    #expect(effective.copiedPaths.isEmpty)

    let planned = try #require(
      harness.model.plannedPath(forBranch: "x", createsBranch: true, in: harness.project)
    )
    #expect(!planned.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path + "/."))
    #expect(planned.path.hasSuffix("-worktrees/x"), "the app default, not the file's")

    await harness.model.createWorktree(
      branch: "x",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
    )
    let worktree = try #require(harness.worktree(onBranch: "x"))
    await harness.model.stageHandles.setupTask(of: worktree.id)?.value
    #expect(
      !FileManager.default.fileExists(
        atPath: worktree.path.appendingPathComponent("id_ed25519").path
      )
    )
    #expect(
      !FileManager.default.fileExists(
        atPath: worktree.path.appendingPathComponent("credentials").path
      )
    )
  }

  /// Asking about a path the app has already refused would show a line that
  /// trusting cannot turn on, and teach the user to say yes to it.
  @Test func theQuestionLeavesOutWhatConfinementHasAlreadyDropped() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings(#"{ "linkedPaths": "~/.ssh/id_ed25519\nvendor" }"#)

    await harness.model.refreshWorktrees(of: harness.project)
    harness.model.select(harness.model.workspace.worktrees(of: harness.project.id)[0])

    let pending = try #require(harness.model.pendingSharedSettingsTrust)
    #expect(pending.trustCoveredText == "linked:\nvendor")
    #expect(!pending.trustCoveredText.contains(".ssh"), "not a line the user is asked to allow")
  }

  /// No yes would turn anything on.
  @Test func aFileWhoseEveryPathIsRefusedIsNeverAskedAbout() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings(
      #"{ "linkedPaths": "~/.ssh/id_ed25519", "copiedPaths": "/etc/passwd" }"#
    )

    await harness.model.refreshWorktrees(of: harness.project)
    harness.model.select(harness.model.workspace.worktrees(of: harness.project.id)[0])

    #expect(harness.model.pendingSharedSettingsTrust == nil)
    harness.model.setTrustsSharedSettings(true, for: harness.project)
    #expect(
      !harness.model.trustsSharedSettings(of: harness.project),
      "and the tab's button has nothing to turn on either",
    )
  }

  /// A touch moves the date without changing the bytes. Recording it anyway
  /// is what stops every tick after re-reading the file.
  @Test func aFileWhoseBytesDidNotChangeStillRecordsItsNewDate() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let shared = SharedProjectSettings(branchPrefix: "team/")
    let later = Date(timeIntervalSince1970: 2)

    harness.model.applySharedSettingsReading(
      SharedSettingsReading(
        loaded: .success(shared),
        modificationDate: Date(timeIntervalSince1970: 1),
        project: harness.project,
      ),
      for: harness.project,
    )
    harness.model.applySharedSettingsReading(
      SharedSettingsReading(
        loaded: .success(shared),
        modificationDate: later,
        project: harness.project,
      ),
      for: harness.project,
    )

    #expect(
      !harness.project.sharedSettingsSnapshot.needsRead(at: later),
      "so the next tick spends no read",
    )
  }

  /// The answer is held against the file's sha256, so a switch back asks
  /// nothing. Real commits: a branch switch is git rewriting the file.
  @Test func switchingBetweenTwoBranchesHooksAsksAboutEachOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let repository = harness.project.path
    func commit(_ json: String, _ message: String) async throws {
      try await TestRepository.commit(
        message,
        files: [SharedProjectSettings.fileName: json],
        in: repository,
        using: harness.git,
      )
    }

    try await commit(#"{ "postCreateHook": "echo main" }"#, "main hooks")
    await harness.model.refreshWorktrees(of: harness.project)
    try harness.answerTrust(true)
    #expect(harness.model.effectiveSettings(for: harness.project).postCreateHook == "echo main")

    // The other branch's file: bytes nobody has answered for, so asked.
    _ = try await harness.git.run(["checkout", "-q", "-b", "feature"], in: repository)
    try await commit(#"{ "postCreateHook": "echo feature" }"#, "feature hooks")
    await harness.model.refreshSharedSettingsIfChanged()
    let feature = try #require(harness.model.pendingSharedSettingsTrust)
    #expect(feature.trustCoveredText == "post-create:\necho feature")
    harness.model.answerSharedSettingsTrust(feature, isTrusted: false)
    #expect(
      !harness.model.trustsSharedSettings(of: harness.project)
    )

    _ = try await harness.git.run(["checkout", "-q", "main"], in: repository)
    await harness.model.refreshSharedSettingsIfChanged()
    #expect(harness.model.pendingSharedSettingsTrust == nil, "answered for already")
    #expect(
      harness.model.trustsSharedSettings(of: harness.project)
    )
    #expect(harness.model.effectiveSettings(for: harness.project).postCreateHook == "echo main")

    _ = try await harness.git.run(["checkout", "-q", "feature"], in: repository)
    await harness.model.refreshSharedSettingsIfChanged()
    #expect(
      harness.model.pendingSharedSettingsTrust == nil,
      "and the no is not asked again either",
    )
    #expect(
      !harness.model.trustsSharedSettings(of: harness.project)
    )
    #expect(harness.model.effectiveSettings(for: harness.project).postCreateHook == "")

    // The answer is against the file's bytes, so a branch that ships the
    // trusted hooks alongside another key is a file of its own and asks.
    _ = try await harness.git.run(["checkout", "-q", "-b", "prefixed", "main"], in: repository)
    try await commit(
      #"{ "branchPrefix": "team/", "postCreateHook": "echo main" }"#,
      "hooks and a prefix",
    )
    await harness.model.refreshSharedSettingsIfChanged()
    #expect(
      harness.model.pendingSharedSettingsTrust?.trustCoveredText == "post-create:\necho main",
      "the same hooks, in bytes nobody has answered for",
    )
  }

  @Test func aSettingsFileEditedWhileTheAppIsUpIsReadOnTheNextTick() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let file = try harness.writeSharedSettings(#"{ "postCreateHook": "echo one" }"#)
    await harness.model.refreshWorktrees(of: harness.project)
    #expect(
      harness.model.pendingSharedSettingsTrust == nil,
      "the first read of a project says nothing",
    )

    // No worktree comes or goes, so the records are the same and the file's
    // date is the only thing that says it changed.
    try #"{ "postCreateHook": "echo two" }"#.write(to: file, atomically: true, encoding: .utf8)
    await harness.model.refreshSharedSettingsIfChanged()
    #expect(
      harness.project.sharedSettingsSnapshot.asWritten?.postCreateHook
        == "echo two"
    )
    #expect(
      harness.model.pendingSharedSettingsTrust == nil,
      "not a project the user is looking at",
    )

    harness.model.select(harness.model.workspace.worktrees(of: harness.project.id)[0])
    let stale = try #require(harness.model.pendingSharedSettingsTrust)

    try #"{ "postCreateHook": "echo two and a half" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await harness.model.refreshProjectsIfChanged()
    let pending = try #require(harness.model.pendingSharedSettingsTrust)
    #expect(
      pending.trustCoveredText == "post-create:\necho two and a half",
      "the question up was about text the file no longer has",
    )

    harness.model.answerSharedSettingsTrust(pending, isTrusted: true)
    #expect(
      harness.model.trustsSharedSettings(of: harness.project)
    )
    #expect(stale.trustCoveredText != pending.trustCoveredText)

    harness.model.newWorktreeRequest = NewWorktreeRequest(projectID: harness.project.id)
    try #"{ "postCreateHook": "echo three and a half" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await harness.model.refreshProjectsIfChanged()
    #expect(
      harness.project.sharedSettingsSnapshot.asWritten?.postCreateHook
        == "echo three and a half"
    )
    #expect(harness.model.pendingSharedSettingsTrust == nil, "the sheet is what is being answered")
    harness.model.newWorktreeRequest = nil

    try #"{ "postCreateHook": "echo three" }"#.write(to: file, atomically: true, encoding: .utf8)
    await harness.model.refreshProjectsIfChanged()

    #expect(
      harness.project.sharedSettingsSnapshot.asWritten?.postCreateHook
        == "echo three"
    )
    #expect(
      harness.model.pendingSharedSettingsTrust?.trustCoveredText == "post-create:\necho three",
      "asked while it is the project on screen",
    )
    #expect(
      !harness.model.trustsSharedSettings(of: harness.project)
    )
  }

  @Test func aBrokenSettingsFileIsAProblemOnTheHooksTabNotAnAlert() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings("not json")
    await harness.model.refreshWorktrees(of: harness.project)
    #expect(harness.model.presentedError == nil)
    #expect(
      harness.project.sharedSettingsSnapshot.problem?.hasPrefix(
        ".multishell.json could not be read"
      )
        == true
    )
    #expect(harness.project.sharedSettingsSnapshot.asWritten == nil)
    #expect(harness.platform.logged.count == 1)
  }

  /// A file that stops parsing leaves no hooks to run, so its question is
  /// dropped the way a deleted file's is.
  @Test func aQuestionGoesAwayWithTheFileItWasAbout() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let file = try harness.writeSharedSettings(#"{ "postCreateHook": "echo one" }"#)
    await harness.model.refreshWorktrees(of: harness.project)
    harness.model.select(harness.model.workspace.worktrees(of: harness.project.id)[0])
    #expect(harness.model.pendingSharedSettingsTrust != nil)

    try "not json".write(to: file, atomically: true, encoding: .utf8)
    await harness.model.refreshSharedSettingsIfChanged()
    #expect(
      harness.model.pendingSharedSettingsTrust == nil,
      "the hooks it named are not the app's any more",
    )

    try #"{ "postCreateHook": "echo one" }"#.write(to: file, atomically: true, encoding: .utf8)
    await harness.model.refreshSharedSettingsIfChanged()
    #expect(harness.model.pendingSharedSettingsTrust != nil, "and comes back when it parses again")
    try FileManager.default.removeItem(at: file)
    await harness.model.refreshSharedSettingsIfChanged()
    #expect(harness.model.pendingSharedSettingsTrust == nil, "nor on a branch with no file")
  }

  /// The confinement verdict is held against the file's bytes, so a branch can
  /// add the symlink without moving them. The disk is asked again at the create.
  @Test func aSymlinkCommittedAfterTheFileWasReadCannotCarryACheckoutOut() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings(#"{ "worktreeDirectory": "trees" }"#)
    await harness.model.refreshWorktrees(of: harness.project)
    try harness.answerTrust(true)

    let elsewhere = harness.root.appendingPathComponent("elsewhere", isDirectory: true)
    try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: harness.project.path.appendingPathComponent("trees"),
      withDestinationURL: elsewhere,
    )

    await harness.model.createWorktree(
      branch: "feat",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
    )

    #expect(
      try FileManager.default.contentsOfDirectory(atPath: elsewhere.path).isEmpty,
      "the link leads out of the checkout, so the file's directory is not in force",
    )
    let created = try #require(harness.worktree(onBranch: "feat"))
    #expect(!created.path.standardizedFileURL.path.hasPrefix(elsewhere.standardizedFileURL.path))
  }

  /// The dropped verdict is stored, so the read that put it there must not be
  /// the last word.
  @Test func takingTheSymlinkAwayBringsTheDirectoryBack() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings(#"{ "worktreeDirectory": "trees" }"#)
    await harness.model.refreshWorktrees(of: harness.project)
    try harness.answerTrust(true)
    let link = harness.project.path.appendingPathComponent("trees")
    let elsewhere = harness.root.appendingPathComponent("elsewhere", isDirectory: true)
    try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: elsewhere)

    _ = await harness.model.reconfineSharedSettings(of: harness.project)
    #expect(harness.project.sharedSettingsSnapshot.confined?.worktreeDirectory == nil)

    try FileManager.default.removeItem(at: link)
    _ = await harness.model.reconfineSharedSettings(of: harness.project)

    #expect(harness.project.sharedSettingsSnapshot.confined?.worktreeDirectory == "trees")
    #expect(
      harness.model.effectiveWorktreeSettings(for: harness.project).worktreeDirectory == "trees"
    )
  }
}
