import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

extension AppModelWorktreeSetupTests {
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
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil, "a path the repository does not have is skipped")
    #expect(
      try String(contentsOf: created.path.appendingPathComponent("seen.txt"), encoding: .utf8)
        == "SECRET=1")
  }

  /// The link list runs before the copy list and the hook, and points at
  /// the repository's own file rather than duplicating it.
  @Test func listedFilesAreLinkedInBeforeTheCopyListAndTheHook() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try FileManager.default.createDirectory(
      at: h.project.path.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    h.model.updateSettings(
      ProjectSettings(
        postCreateHook: "cp .env seen.txt", linkedPaths: "node_modules", copiedPaths: ".env"),
      for: h.project)

    await h.model.createWorktree(branch: "linked", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "linked"))
    // Read before the setup task has had the actor: the stage the pane
    // opens on is the link list, whatever else the project has.
    #expect(h.model.worktreeOperations[created.id]?.step == .linkingFiles)
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil)
    #expect(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: created.path.appendingPathComponent("node_modules").path)
        == h.project.path.appendingPathComponent("node_modules").path)
    #expect(
      try String(contentsOf: created.path.appendingPathComponent("seen.txt"), encoding: .utf8)
        == "SECRET=1", "and the copy list, then the hook, ran after it")
    #expect(h.model.worktreeOperations[created.id] == nil, "every stage ended")
  }

  /// The promise a failed stage makes: the list after it and the hook
  /// after that do not run, so one clear failure does not become two.
  @Test func aFailedLinkListStopsTheCopyListAndTheHookAndHoldsTheFirstTab() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try h.divertARepositoryPathWithASymlink()
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    try h.shipSharedSettings(
      #"""
      { "linkedPaths": "link/key", "copiedPaths": ".env",
        "postCreateHook": "echo ran > hook.txt" }
      """#)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)

    await h.model.createWorktree(branch: "stuck", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "stuck"))
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil, "not an alert the sheet's dismissal would drop")
    let shown = try #require(h.model.worktreeOperations[created.id])
    #expect(shown.title == "Some files were not linked into the worktree")
    #expect(shown.failure?.contains("link/key") == true)
    let manager = FileManager.default
    #expect(
      !manager.fileExists(atPath: created.path.appendingPathComponent(".env").path),
      "the copy list after it did not run")
    #expect(!manager.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path))
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "held back until dismissed")

    h.model.dismissOperationFailure(of: created)
    #expect(h.model.worktreeOperations[created.id] == nil)
    #expect(!h.model.workspace.tabs(in: created.id).isEmpty, "and Dismiss hands the worktree over")
  }

  /// A link list reads the reader's own checkout, so it waits for the same
  /// yes the hook beside it waits for, and one answer covers the file.
  @Test func aRepositorysLinkListWaitsForTheTrustQuestionLikeItsHooks() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try FileManager.default.createDirectory(
      at: h.project.path.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
    try #"{ "linkedPaths": "node_modules", "postCreateHook": "echo ran > hook.txt" }"#
      .write(
        to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)

    await h.model.createWorktree(branch: "shared", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "shared"))
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(
      !FileManager.default.fileExists(
        atPath: created.path.appendingPathComponent("node_modules").path),
      "untrusted, so the list did not apply")
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and neither did the hook beside it in the same file")
    #expect(h.model.worktreeOperations[created.id] == nil, "the link stage ended")

    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)
    await h.model.createWorktree(branch: "trusted", basedOn: nil, createBranch: true, in: h.project)
    let second = try #require(h.worktree(onBranch: "trusted"))
    await h.model.stageHandles.setup(of: second.id)?.value

    #expect(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: second.path.appendingPathComponent("node_modules").path)
        == h.project.path.appendingPathComponent("node_modules").path,
      "and once trusted the link list applies")
  }

  /// A file list has no process to signal, so Cancel is asked per path. The
  /// worktree is handed over the way a stopped hook hands it over.
  @Test func cancelOnAFileListEndsTheSetupAndHandsTheWorktreeOver() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "echo ran > hook.txt", copiedPaths: ".env"), for: h.project)

    await h.model.createWorktree(branch: "halted", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "halted"))
    // Before the setup task has had the actor: the stage's handle is made
    // early so the stop lands at its first path, not in a race with it.
    #expect(h.model.worktreeOperations[created.id]?.step == .copyingFiles)
    h.model.cancelStage(of: created)
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil, "a stop is the user's own doing, not a failure")
    #expect(h.model.worktreeOperations[created.id] == nil, "the stage ended rather than failing")
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent(".env").path))
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and the hook after it did not run")
    #expect(!h.model.workspace.tabs(in: created.id).isEmpty, "the worktree is the user's to use")
  }

  /// A copy list reads the reader's own checkout, git-ignored files
  /// included, so like the hooks beside it in the file it waits.
  @Test func aRepositorysCopyListWaitsForTheTrustQuestionLikeItsHooks() async throws {
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
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent(".env").path),
      "untrusted, so the copy list did not apply")
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and neither did the hook beside it in the same file")
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
    try h.divertARepositoryPathWithASymlink()
    try h.shipSharedSettings(
      #"{ "copiedPaths": "link/key", "postCreateHook": "echo ran > hook.txt" }"#)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)

    await h.model.createWorktree(branch: "escaped", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "escaped"))
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil, "not an alert the sheet's dismissal would drop")
    let shown = try #require(h.model.worktreeOperations[created.id])
    #expect(shown.title == "Some files were not copied into the worktree")
    #expect(shown.failure?.contains("link/key") == true)
    #expect(
      !FileManager.default.fileExists(
        atPath: created.path.appendingPathComponent("hook.txt").path),
      "the hook did not run")
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "held back until dismissed")

    h.model.dismissOperationFailure(of: created)
    #expect(h.model.worktreeOperations[created.id] == nil)
  }

  /// A list the user typed is theirs, `RepositoryContainment` holding only
  /// what a repository ships; an entry reaching out is skipped, not refused.
  @Test func skippedEntriesAreStillNamedWhenALaterListFails() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let locked = h.project.path.appendingPathComponent("locked.txt")
    try "x".write(to: locked, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)
    defer {
      try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path)
    }
    h.model.updateSettings(
      ProjectSettings(linkedPaths: "~/.aws.json", copiedPaths: "locked.txt"), for: h.project)

    await h.model.createWorktree(branch: "mine", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "mine"))
    await h.model.stageHandles.setup(of: created.id)?.value

    let shown = try #require(h.model.worktreeOperations[created.id])
    #expect(!shown.isRunning, "the copy failed")
    #expect(shown.failure?.contains("locked.txt") == true)
    #expect(shown.failure?.contains("~/.aws.json") == true, "on the one failure that is shown")
    #expect(h.model.presentedError == nil, "not a second message racing it for the one alert")
  }

  @Test func aCancelledListStillNamesTheEntriesItSkippedBeforeTheStop() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    h.model.updateSettings(ProjectSettings(copiedPaths: "~/.aws.json\n.env"), for: h.project)

    await h.model.createWorktree(branch: "mine", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "mine"))
    h.model.cancelStage(of: created)
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(h.model.worktreeOperations[created.id] == nil, "the stage ended rather than failing")
    #expect(h.model.presentedError?.message.contains("~/.aws.json") == true)
  }

  @Test func aPathTheUserListedThemselvesDoesNotStopTheStagesAfterIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "echo ran > hook.txt", copiedPaths: "~/.aws.json\n.env"),
      for: h.project)

    await h.model.createWorktree(branch: "mine", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "mine"))
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(h.model.worktreeOperations[created.id] == nil, "every stage ended")
    let manager = FileManager.default
    #expect(manager.fileExists(atPath: created.path.appendingPathComponent(".env").path))
    #expect(
      manager.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and the hook after the list ran")
    #expect(h.model.presentedError?.message.contains("~/.aws.json") == true)
  }

  /// The user's own list replaces the repository's whole, so what is placed
  /// is theirs and is not held to the checkout, file on disk or not.
  @Test func theUsersOwnListOverridingTheRepositorysIsStillTheirs() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let secret = h.root.appendingPathComponent("secrets.txt")
    try "SECRET=1".write(to: secret, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: h.project.path.appendingPathComponent(".env"), withDestinationURL: secret)
    try h.shipSharedSettings(#"{ "copiedPaths": "vendor" }"#)
    await h.model.refresh(h.project)
    h.model.updateSettings(
      h.project.settings.with { $0.copiedPaths = ".env" }, for: h.project)

    await h.model.createWorktree(branch: "mine", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "mine"))
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(h.model.worktreeOperations[created.id] == nil, "the stage ended rather than failing")
    #expect(
      try String(contentsOf: created.path.appendingPathComponent(".env"), encoding: .utf8)
        == "SECRET=1", "and their symlinked file was placed")
  }
}
