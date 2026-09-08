import Foundation
import MultishellCore
import MultishellGitKit
import Testing

@testable import MultishellAppCore

/// Bare repositories, the hook timeout and Stop Hook, removal through the
/// Trash, and the repository's own settings file, on the model with real git.
@Suite(.serialized) @MainActor
struct AppModelHookControlTests {
  @Test func aBareCloneIsAddedAsAProjectWithItsBareEntryFirst() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let bare = h.root.appendingPathComponent("repo.git", isDirectory: true)
    _ = try await h.git.run(["clone", "-q", "--bare", h.project.path.path, bare.path], in: h.root)
    let checkout = h.root.appendingPathComponent("checkout", isDirectory: true)
    _ = try await h.git.run(["worktree", "add", "-q", checkout.path, "main"], in: bare)

    await h.model.addProject(at: checkout)

    #expect(h.model.presentedError == nil)
    let project = try #require(h.model.workspace.project(bare.standardizedFileURL.path))
    #expect(project.name == "repo")
    let worktrees = h.model.workspace.worktrees(of: project.id)
    #expect(worktrees.map(\.isBare) == [true, false])
    #expect(worktrees[0].isPrimary && worktrees[1].branch == "main")
    await h.model.refreshStatuses()
    #expect(h.model.statuses[worktrees[0].id] == nil, "no status poll for the bare entry")
    #expect(h.model.statuses[worktrees[1].id] != nil)
  }

  @Test func aPostCreateHookPastTheTimeoutIsStoppedAndThePaneSaysItDidNotFinish() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setHookTimeoutSeconds(1)
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "echo installing\nsleep 30"), for: h.project)
    let started = ContinuousClock.now

    await h.model.createWorktree(branch: "slow", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "slow"))
    await h.model.worktreeSetups[created.id]?.value

    #expect(ContinuousClock.now - started < .seconds(10))
    let failed = try #require(h.model.worktreeOperations[created.id])
    #expect(failed.timedOut && failed.title == "The post-create hook did not finish")
    #expect(failed.failure == "installing\n\nStopped after 1 second, the hook timeout.")
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "held back until dismissed")
  }

  /// The copy runs between `git worktree add` and the hook, so the hook
  /// finds what it was given: an `npm install` wants the `.env` first.
  @Test func listedFilesAreCopiedInBeforeThePostCreateHookRuns() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "cp .env seen.txt", copiedPaths: ".env\nmissing.env"),
      for: h.project)

    await h.model.createWorktree(branch: "copied", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "copied"))
    await h.model.worktreeSetups[created.id]?.value

    #expect(h.model.presentedError == nil, "a path the repository does not have is skipped")
    #expect(
      try String(contentsOf: created.path.appendingPathComponent("seen.txt"), encoding: .utf8)
        == "SECRET=1")
  }

  /// A copy list runs nothing, so unlike the hooks beside it in the file
  /// it does not wait for the trust question.
  @Test func aRepositorysCopyListAppliesWithoutTheTrustQuestion() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    try #"{ "copiedPaths": ".env", "postCreateHook": "echo ran > hook.txt" }"#
      .write(
        to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)

    await h.model.createWorktree(branch: "shared", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "shared"))
    await h.model.worktreeSetups[created.id]?.value

    #expect(
      FileManager.default.fileExists(atPath: created.path.appendingPathComponent(".env").path),
      "the copy list applied")
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "the hook beside it in the same file still waited to be trusted")
    #expect(h.model.worktreeOperations[created.id] == nil, "the copy stage ended")
    #expect(
      !h.model.workspace.tabs(in: created.id).isEmpty,
      "and the first terminal opened once it had, with no hook to wait for")
  }

  /// The alert would be raised as the sheet went away, which is where one
  /// gets dropped, so a failed copy goes to the pane and holds the tab.
  @Test func aFailedCopyShowsInThePaneAndKeepsThePostCreateHookFromRunning() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let outside = h.root.appendingPathComponent("outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try "SECRET=1".write(
      to: outside.appendingPathComponent("key"), atomically: true, encoding: .utf8)
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "echo ran > hook.txt", copiedPaths: "../outside/key"),
      for: h.project)

    await h.model.createWorktree(branch: "escaped", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "escaped"))
    await h.model.worktreeSetups[created.id]?.value

    #expect(h.model.presentedError == nil, "not an alert the sheet's dismissal would drop")
    let shown = try #require(h.model.worktreeOperations[created.id])
    #expect(shown.title == "Some files were not copied into the worktree")
    #expect(shown.failure?.contains("../outside/key") == true)
    #expect(
      !FileManager.default.fileExists(
        atPath: created.path.appendingPathComponent("hook.txt").path),
      "the hook did not run")
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "held back until dismissed")

    h.model.dismissOperationFailure(of: created)
    #expect(h.model.worktreeOperations[created.id] == nil)
  }

  @Test func stopHookEndsAPostCreateHookAndHandsTheWorktreeOver() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 30"), for: h.project)

    await h.model.createWorktree(branch: "stopped", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "stopped"))
    #expect(h.model.worktreeOperations[created.id]?.isRunning == true)
    h.model.stopHook(of: created)
    await h.model.worktreeSetups[created.id]?.value

    #expect(h.model.worktreeOperations[created.id] == nil, "nothing to dismiss")
    #expect(h.model.presentedError == nil)
    #expect(
      h.model.workspace.tabs(in: created.id).count == 1, "the first tab opens as after a finish")
  }

  @Test func stopHookOnAPreDeleteHookLeavesTheWorktreeQuietly() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "kept", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "kept"))
    h.model.updateSettings(ProjectSettings(preDeleteHook: "sleep 30"), for: h.project)
    h.model.setConfirmsWorktreeRemoval(false)
    h.model.setDeletesBranchWithWorktree(true)

    h.model.requestRemoval(of: worktree)
    try await Task.sleep(for: .milliseconds(300))
    #expect(h.model.worktreeOperations[worktree.id]?.step == .preDeleteHook)
    h.model.stopHook(of: worktree)
    await h.awaitOperationEnd(on: worktree.id)

    #expect(h.model.worktreeOperations[worktree.id] == nil)
    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "kept") != nil && h.model.liveTerminalCount == 1)
  }

  @Test func cancellingTheSheetDuringThePreCreateHookCreatesNothingAndSaysNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(preCreateHook: "sleep 30"), for: h.project)
    let create = Task {
      await h.model.createWorktree(branch: "never", basedOn: nil, createBranch: true, in: h.project)
    }
    try await Task.sleep(for: .milliseconds(300))
    #expect(h.model.worktreeCreationStep == .preCreateHook)

    h.model.cancelWorktreeCreation()
    await create.value

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "never") == nil)
    #expect(h.model.worktreeCreationStep == nil)
  }

  @Test func aLockedWorktreeIsUnlockedSoThePruneTakesIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "locked", basedOn: nil, createBranch: true, in: h.project)
    var worktree = try #require(h.worktree(onBranch: "locked"))
    _ = try await h.git.run(["worktree", "lock", worktree.path.path], in: h.project.path)
    await h.model.refresh(h.project)
    worktree = try #require(h.worktree(onBranch: "locked"))
    #expect(worktree.isLocked)

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "locked") == nil, "no record left behind")
    #expect(h.platform.trashed == [worktree.path])
  }

  @Test func aTrashThatRefusesFallsBackToDeletingTheDirectory() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "stuck", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "stuck"))
    h.platform.trash = nil

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "stuck") == nil)
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path), "deleted outright")
    #expect(h.platform.logged.count == 1, "the fallback leaves a line in the log")
  }

  @Test func aDirectoryThatCanBeNeitherTrashedNorDeletedKeepsTheWorktree() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "pinned", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "pinned"))
    h.platform.trash = nil
    // A read-only parent refuses the unlink of its entries.
    let container = worktree.path.deletingLastPathComponent()
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: container.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: container.path)
    }

    await h.model.removeWorktree(worktree)

    let alert = try #require(h.model.presentedError)
    #expect(alert.title.hasPrefix("Worktree not removed: the directory could not be moved"))
    #expect(alert.retryLabel == nil)
    #expect(h.worktree(onBranch: "pinned") != nil && h.model.worktreeOperations.isEmpty)
    #expect(FileManager.default.fileExists(atPath: worktree.path.path))
    #expect(h.model.liveTerminalCount == 1, "the shell is still there")
  }

  @Test func theRepositorysSettingsFileFillsTheGapsAndItsHooksWaitForTrust() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try
      #"{ "branchPrefix": "team/", "worktreeDirectory": "../shared-trees", "postCreateHook": "echo shared > hook.txt", "iconGlyph": "hammer" }"#
      .write(to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)

    await h.model.refresh(h.project)

    #expect(h.model.sharedSettings[h.project.id]?.branchPrefix == "team/")
    #expect(h.model.worktreeSettings(for: h.project).branchPrefix == "team/")
    #expect(h.model.effectiveSettings(for: h.project).iconGlyph == "hammer")
    #expect(
      h.model.plannedPath(forBranch: "x", createBranch: true, in: h.project)?.path.hasSuffix(
        "/shared-trees/team-x") == true)
    #expect(h.model.pendingSharedHooksTrust == nil, "not asked until the user turns to it")
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let pending = try #require(h.model.pendingSharedHooksTrust)
    #expect(pending.projectID == h.project.id && pending.hooks.contains("echo shared"))
    #expect(!h.model.trustsSharedHooks(of: h.project))

    // Untrusted: the create runs no hook, and its own select does not ask.
    h.model.pendingSharedHooksTrust = nil
    await h.model.createWorktree(branch: "a", basedOn: nil, createBranch: true, in: h.project)
    #expect(h.model.pendingSharedHooksTrust == nil, "the sheet is still going away then")
    let a = try #require(h.worktree(onBranch: "team/a"))
    #expect(h.model.worktreeSetups[a.id] == nil)
    #expect(!FileManager.default.fileExists(atPath: a.path.appendingPathComponent("hook.txt").path))

    h.model.decideSharedHooks(pending, trusted: true)
    #expect(h.model.pendingSharedHooksTrust == nil)
    #expect(h.model.trustsSharedHooks(of: h.project))
    await h.model.createWorktree(branch: "b", basedOn: nil, createBranch: true, in: h.project)
    let b = try #require(h.worktree(onBranch: "team/b"))
    await h.model.worktreeSetups[b.id]?.value
    #expect(FileManager.default.fileExists(atPath: b.path.appendingPathComponent("hook.txt").path))

    // The user's own prefix wins; a changed hook asks again.
    h.model.updateSettings(
      with(h.model.workspace.project(h.project.id)!.settings) { $0.branchPrefix = "me/" },
      for: h.project)
    #expect(h.model.worktreeSettings(for: h.project).branchPrefix == "me/")
    try #"{ "postCreateHook": "echo changed" }"#
      .write(to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    #expect(!h.model.trustsSharedHooks(of: h.project))
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    #expect(h.model.pendingSharedHooksTrust?.hooks == "post-create:\necho changed")
  }

  @Test func aSettingsFileEditedWhileTheAppIsUpIsReadOnTheNextTick() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "postCreateHook": "echo one" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    #expect(h.model.pendingSharedHooksTrust == nil, "the first read of a project says nothing")

    // No worktree comes or goes, so the records are the same and the file's
    // date is the only thing that says it changed.
    try #"{ "postCreateHook": "echo two" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshChangedSharedSettings()
    #expect(h.model.sharedSettings[h.project.id]?.postCreateHook == "echo two")
    #expect(h.model.pendingSharedHooksTrust == nil, "not a project the user is looking at")

    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let stale = try #require(h.model.pendingSharedHooksTrust)

    // The file moves on while its question is still up.
    try #"{ "postCreateHook": "echo two and a half" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshWorktreesIfRecordsChanged()
    let pending = try #require(h.model.pendingSharedHooksTrust)
    #expect(
      pending.hooks == "post-create:\necho two and a half",
      "the question up was about text the file no longer has")

    h.model.decideSharedHooks(pending, trusted: true)
    #expect(h.model.trustsSharedHooks(of: h.model.workspace.project(h.project.id)!))
    #expect(stale.hooks != pending.hooks)

    // Not over the new-worktree sheet, which the user is answering.
    h.model.newWorktreeRequest = NewWorktreeRequest(projectID: h.project.id)
    try #"{ "postCreateHook": "echo three and a half" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshWorktreesIfRecordsChanged()
    #expect(h.model.sharedSettings[h.project.id]?.postCreateHook == "echo three and a half")
    #expect(h.model.pendingSharedHooksTrust == nil, "the sheet is what is being answered")
    h.model.newWorktreeRequest = nil

    try #"{ "postCreateHook": "echo three" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshWorktreesIfRecordsChanged()

    #expect(h.model.sharedSettings[h.project.id]?.postCreateHook == "echo three")
    #expect(
      h.model.pendingSharedHooksTrust?.hooks == "post-create:\necho three",
      "asked while it is the project on screen")
    #expect(!h.model.trustsSharedHooks(of: h.model.workspace.project(h.project.id)!))
  }

  @Test func aBrokenSettingsFileIsAProblemOnTheHooksTabNotAnAlert() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "not json".write(
      to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    #expect(h.model.presentedError == nil)
    #expect(
      h.model.sharedSettingsProblems[h.project.id]?.hasPrefix(".multishell.json could not be read")
        == true)
    #expect(h.model.sharedSettings[h.project.id] == nil)
    #expect(h.platform.logged.count == 1)
  }

  @Test func exportWritesTheSettingsInForceAndTrustsItsOwnHooks() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(
      ProjectSettings(
        branchPrefix: "team/", postCreateHook: "npm ci", copiedPaths: ".env\n.env.*",
        iconGlyph: "🚀", iconTint: 3),
      for: h.project)

    h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.branchPrefix == "team/" && written.postCreateHook == "npm ci")
    #expect(written.iconGlyph == "🚀" && written.iconTint == 3)
    #expect(written.copiedPaths == ".env\n.env.*", "the copy list travels with the hooks")
    #expect(written.hooksText?.contains(".env") != true, "but is not part of the hook question")
    #expect(written.worktreeDirectory == nil, "following the global is not exported")
    #expect(h.model.sharedSettings[h.project.id] == written)
    #expect(h.model.pendingSharedHooksTrust == nil, "the hooks are the user's own words")
    #expect(h.model.trustsSharedHooks(of: h.model.workspace.project(h.project.id)!))
    let text = try String(
      contentsOf: SharedProjectSettings.file(in: h.project.path), encoding: .utf8)
    #expect(text.hasPrefix("{\n  \"branchPrefix\""), "sorted and indented for a diff")
  }
}

private func with(
  _ settings: ProjectSettings, _ change: (inout ProjectSettings) -> Void
)
  -> ProjectSettings
{
  var updated = settings
  change(&updated)
  return updated
}
