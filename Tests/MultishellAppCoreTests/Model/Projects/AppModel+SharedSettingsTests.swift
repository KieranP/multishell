import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelSharedSettingsTests {
  @Test func theRepositorysSettingsFileFillsTheGapsAndItsHooksWaitForTrust() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try
      #"{ "branchPrefix": "team/", "worktreeDirectory": ".shared-trees", "postCreateHook": "echo shared > hook.txt", "iconGlyph": "hammer" }"#
      .write(to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)

    await h.model.refresh(h.project)

    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.asWritten?.branchPrefix == "team/")
    #expect(h.model.worktreeSettings(for: h.project).branchPrefix == "team/")
    #expect(h.model.effectiveSettings(for: h.project).iconGlyph == "hammer")
    #expect(
      h.model.plannedPath(forBranch: "x", createBranch: true, in: h.project)?.path.hasSuffix(
        "/.shared-trees/team-x") == false,
      "where a checkout lands waits for trust, unlike the prefix and the icon")
    #expect(h.model.pendingSharedSettingsTrust == nil, "not asked until the user turns to it")
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let pending = try #require(h.model.pendingSharedSettingsTrust)
    #expect(pending.projectID == h.project.id && pending.trustCoveredText.contains("echo shared"))
    #expect(!h.model.trustsSharedSettings(of: h.project))

    // Untrusted: the create runs no hook, and its own select does not ask.
    h.model.pendingSharedSettingsTrust = nil
    await h.model.createWorktree(branch: "a", basedOn: nil, createBranch: true, in: h.project)
    #expect(h.model.pendingSharedSettingsTrust == nil, "the sheet is still going away then")
    let a = try #require(h.worktree(onBranch: "team/a"))
    #expect(h.model.stageHandles.setup(of: a.id) == nil)
    #expect(!FileManager.default.fileExists(atPath: a.path.appendingPathComponent("hook.txt").path))

    h.model.decideSharedSettings(pending, trusted: true)
    #expect(h.model.pendingSharedSettingsTrust == nil)
    #expect(h.model.trustsSharedSettings(of: h.project))
    #expect(
      h.model.plannedPath(forBranch: "x", createBranch: true, in: h.project)?.path.hasSuffix(
        "/.shared-trees/team-x") == true,
      "and once trusted the file's directory is the one used")
    await h.model.createWorktree(branch: "b", basedOn: nil, createBranch: true, in: h.project)
    let b = try #require(h.worktree(onBranch: "team/b"))
    await h.model.stageHandles.setup(of: b.id)?.value
    #expect(FileManager.default.fileExists(atPath: b.path.appendingPathComponent("hook.txt").path))

    // The user's own prefix wins; a changed hook asks again.
    h.model.updateSettings(
      h.model.workspace.project(h.project.id)!.settings.with { $0.branchPrefix = "me/" },
      for: h.project)
    #expect(h.model.worktreeSettings(for: h.project).branchPrefix == "me/")
    try #"{ "postCreateHook": "echo changed" }"#
      .write(to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    #expect(!h.model.trustsSharedSettings(of: h.project))
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    #expect(h.model.pendingSharedSettingsTrust?.trustCoveredText == "post-create:\necho changed")
  }

  /// What a committed file names outside the checkout is dropped, and the
  /// reader's own settings stand; see Docs/design/settings.md.
  @Test func aSettingsFileCannotPlaceAWorktreeOrReadFilesOutsideTheCheckout() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let key = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".ssh/id_ed25519").path
    let json = """
      { "worktreeDirectory": "~/.claude/skills", \
      "linkedPaths": "\(key)\\nvendor", "copiedPaths": "../../.aws/credentials" }
      """
    try json.write(
      to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)

    await h.model.refresh(h.project)
    // Trusted, so what is dropped here is dropped for reaching out and not
    // for waiting on an answer.
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)

    let effective = h.model.effectiveSettings(for: h.project)
    #expect(effective.worktreeDirectory == nil, "the reader's own directory stands")
    #expect(effective.linkedPaths == "vendor", "only the entry reaching out is dropped")
    #expect(effective.copiedPaths.isEmpty)

    let planned = try #require(
      h.model.plannedPath(forBranch: "x", createBranch: true, in: h.project))
    #expect(!planned.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path + "/."))
    #expect(planned.path.hasSuffix("-worktrees/x"), "the app default, not the file's")

    await h.model.createWorktree(branch: "x", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "x"))
    await h.model.stageHandles.setup(of: worktree.id)?.value
    #expect(
      !FileManager.default.fileExists(
        atPath: worktree.path.appendingPathComponent("id_ed25519").path))
    #expect(
      !FileManager.default.fileExists(
        atPath: worktree.path.appendingPathComponent("credentials").path))
  }

  /// Asking about a path the app has already refused would show a line that
  /// trusting cannot turn on, and teach the user to say yes to it.
  @Test func theQuestionLeavesOutWhatConfinementHasAlreadyDropped() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try #"{ "linkedPaths": "~/.ssh/id_ed25519\nvendor" }"#
      .write(to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)

    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])

    let pending = try #require(h.model.pendingSharedSettingsTrust)
    #expect(pending.trustCoveredText == "linked:\nvendor")
    #expect(!pending.trustCoveredText.contains(".ssh"), "not a line the user is asked to allow")
  }

  /// And a file whose every path is refused asks nothing at all: there is
  /// no longer anything a yes would turn on.
  @Test func aFileWhoseEveryPathIsRefusedIsNeverAskedAbout() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try #"{ "linkedPaths": "~/.ssh/id_ed25519", "copiedPaths": "/etc/passwd" }"#
      .write(to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)

    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])

    #expect(h.model.pendingSharedSettingsTrust == nil)
    h.model.setTrustsSharedSettings(true, for: h.project)
    #expect(
      !h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!),
      "and the tab's button has nothing to turn on either")
  }

  /// A touch moves the date without changing the bytes. Recording it anyway
  /// is what stops every tick after re-reading the file.
  @Test func aFileWhoseBytesDidNotChangeStillRecordsItsNewDate() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let shared = SharedProjectSettings(branchPrefix: "team/")
    let later = Date(timeIntervalSince1970: 2)

    h.model.applySharedSettingsReading(
      SharedSettingsReading(
        result: .success(shared), stamp: Date(timeIntervalSince1970: 1), project: h.project),
      for: h.project)
    h.model.applySharedSettingsReading(
      SharedSettingsReading(result: .success(shared), stamp: later, project: h.project),
      for: h.project)

    #expect(!h.project.sharedSettings.hasMoved(later), "so the next tick spends no read")
  }

  /// The answer is held against the file's sha256, so a switch back asks
  /// nothing. Real commits: a branch switch is git rewriting the file.
  @Test func switchingBetweenTwoBranchesHooksAsksAboutEachOnce() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let repository = h.project.path
    let file = SharedProjectSettings.file(in: repository)
    func commit(_ json: String, _ message: String) async throws {
      try json.write(to: file, atomically: true, encoding: .utf8)
      _ = try await h.git.run(["add", "."], in: repository)
      _ = try await h.git.run(["commit", "-q", "-m", message], in: repository)
    }

    try await commit(#"{ "postCreateHook": "echo main" }"#, "main hooks")
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)
    #expect(h.model.effectiveSettings(for: h.project).postCreateHook == "echo main")

    // The other branch's file: bytes nobody has answered for, so asked.
    _ = try await h.git.run(["checkout", "-q", "-b", "feature"], in: repository)
    try await commit(#"{ "postCreateHook": "echo feature" }"#, "feature hooks")
    await h.model.refreshSharedSettingsIfChanged()
    let feature = try #require(h.model.pendingSharedSettingsTrust)
    #expect(feature.trustCoveredText == "post-create:\necho feature")
    h.model.decideSharedSettings(feature, trusted: false)
    #expect(!h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))

    // Back to the first branch: the yes it was given stands, unasked.
    _ = try await h.git.run(["checkout", "-q", "main"], in: repository)
    await h.model.refreshSharedSettingsIfChanged()
    #expect(h.model.pendingSharedSettingsTrust == nil, "answered for already")
    #expect(h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
    #expect(h.model.effectiveSettings(for: h.project).postCreateHook == "echo main")

    // And back to the other: its no stands, also unasked.
    _ = try await h.git.run(["checkout", "-q", "feature"], in: repository)
    await h.model.refreshSharedSettingsIfChanged()
    #expect(h.model.pendingSharedSettingsTrust == nil, "and the no is not asked again either")
    #expect(!h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
    #expect(h.model.effectiveSettings(for: h.project).postCreateHook == "")

    // The answer is against the file's bytes, so a branch that ships the
    // trusted hooks alongside another key is a file of its own and asks.
    _ = try await h.git.run(["checkout", "-q", "-b", "prefixed", "main"], in: repository)
    try await commit(
      #"{ "branchPrefix": "team/", "postCreateHook": "echo main" }"#, "hooks and a prefix")
    await h.model.refreshSharedSettingsIfChanged()
    #expect(
      h.model.pendingSharedSettingsTrust?.trustCoveredText == "post-create:\necho main",
      "the same hooks, in bytes nobody has answered for")
  }

  @Test func aSettingsFileEditedWhileTheAppIsUpIsReadOnTheNextTick() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "postCreateHook": "echo one" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    #expect(h.model.pendingSharedSettingsTrust == nil, "the first read of a project says nothing")

    // No worktree comes or goes, so the records are the same and the file's
    // date is the only thing that says it changed.
    try #"{ "postCreateHook": "echo two" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshSharedSettingsIfChanged()
    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.asWritten?.postCreateHook
        == "echo two")
    #expect(h.model.pendingSharedSettingsTrust == nil, "not a project the user is looking at")

    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let stale = try #require(h.model.pendingSharedSettingsTrust)

    // The file moves on while its question is still up.
    try #"{ "postCreateHook": "echo two and a half" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshWorktreesIfRecordsChanged()
    let pending = try #require(h.model.pendingSharedSettingsTrust)
    #expect(
      pending.trustCoveredText == "post-create:\necho two and a half",
      "the question up was about text the file no longer has")

    h.model.decideSharedSettings(pending, trusted: true)
    #expect(h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
    #expect(stale.trustCoveredText != pending.trustCoveredText)

    // Not over the new-worktree sheet, which the user is answering.
    h.model.newWorktreeRequest = NewWorktreeRequest(projectID: h.project.id)
    try #"{ "postCreateHook": "echo three and a half" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshWorktreesIfRecordsChanged()
    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.asWritten?.postCreateHook
        == "echo three and a half")
    #expect(h.model.pendingSharedSettingsTrust == nil, "the sheet is what is being answered")
    h.model.newWorktreeRequest = nil

    try #"{ "postCreateHook": "echo three" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshWorktreesIfRecordsChanged()

    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.asWritten?.postCreateHook
        == "echo three")
    #expect(
      h.model.pendingSharedSettingsTrust?.trustCoveredText == "post-create:\necho three",
      "asked while it is the project on screen")
    #expect(!h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
  }

  @Test func aBrokenSettingsFileIsAProblemOnTheHooksTabNotAnAlert() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "not json".write(
      to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    #expect(h.model.presentedError == nil)
    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.problem?.hasPrefix(
        ".multishell.json could not be read")
        == true)
    #expect(h.model.workspace.project(h.project.id)?.sharedSettings.asWritten == nil)
    #expect(h.platform.logged.count == 1)
  }

  /// A file that stops parsing leaves no hooks to run, so its question is
  /// dropped the way a deleted file's is.
  @Test func aQuestionGoesAwayWithTheFileItWasAbout() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "postCreateHook": "echo one" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    #expect(h.model.pendingSharedSettingsTrust != nil)

    try "not json".write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshSharedSettingsIfChanged()
    #expect(
      h.model.pendingSharedSettingsTrust == nil, "the hooks it named are not the app's any more")

    // The same for a branch that carries no file at all.
    try #"{ "postCreateHook": "echo one" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshSharedSettingsIfChanged()
    #expect(h.model.pendingSharedSettingsTrust != nil, "and comes back when it parses again")
    try FileManager.default.removeItem(at: file)
    await h.model.refreshSharedSettingsIfChanged()
    #expect(h.model.pendingSharedSettingsTrust == nil)
  }

  /// The confinement verdict is held against the file's bytes, so a branch can
  /// add the symlink without moving them. The disk is asked again at the create.
  @Test func aSymlinkCommittedAfterTheFileWasReadCannotCarryACheckoutOut() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "worktreeDirectory": "trees" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let asked = try #require(h.model.pendingSharedSettingsTrust)
    h.model.decideSharedSettings(asked, trusted: true)

    let elsewhere = h.root.appendingPathComponent("elsewhere", isDirectory: true)
    try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: h.project.path.appendingPathComponent("trees"), withDestinationURL: elsewhere)

    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)

    #expect(
      try FileManager.default.contentsOfDirectory(atPath: elsewhere.path).isEmpty,
      "the link leads out of the checkout, so the file's directory is not in force")
    let created = try #require(h.worktree(onBranch: "feat"))
    #expect(!created.path.standardizedFileURL.path.hasPrefix(elsewhere.standardizedFileURL.path))
  }

  /// The dropped verdict is stored, so the read that put it there must not be
  /// the last word: taking the symlink away brings the directory back.
  @Test func takingTheSymlinkAwayBringsTheDirectoryBack() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "worktreeDirectory": "trees" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)
    let link = h.project.path.appendingPathComponent("trees")
    let elsewhere = h.root.appendingPathComponent("elsewhere", isDirectory: true)
    try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: elsewhere)

    _ = await h.model.reconfineSharedSettings(of: h.project)
    #expect(h.project.sharedSettings.confined?.worktreeDirectory == nil)

    try FileManager.default.removeItem(at: link)
    _ = await h.model.reconfineSharedSettings(of: h.project)

    #expect(h.project.sharedSettings.confined?.worktreeDirectory == "trees")
    #expect(h.model.worktreeSettings(for: h.project).worktreeDirectory == "trees")
  }
}
