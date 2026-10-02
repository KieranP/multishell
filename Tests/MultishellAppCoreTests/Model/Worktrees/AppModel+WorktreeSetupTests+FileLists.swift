import Foundation
import MultishellProcess
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelWorktreeSetupTests {
  /// An untracked `.env` in the repository, the file the lists are meant to carry.
  private func plantEnvFile(_ harness: GitHarness) throws {
    try "SECRET=1".write(
      to: harness.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
  }

  /// The copy runs between `git worktree add` and the hook, so the hook
  /// finds what it was given: an `npm install` wants the `.env` first.
  @Test func listedFilesAreCopiedInBeforeThePostCreateHookRuns() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try plantEnvFile(harness)
    harness.model.setSettings(
      ProjectSettings(postCreateHook: "cp .env seen.txt", copiedPaths: ".env\nmissing.env"),
      for: harness.project)

    await harness.model.createWorktree(
      branch: "copied", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "copied"))
    await harness.model.stageHandles.setup(of: created.id)?.value

    #expect(harness.model.presentedError == nil, "a path the repository does not have is skipped")
    #expect(
      try String(contentsOf: created.path.appendingPathComponent("seen.txt"), encoding: .utf8)
        == "SECRET=1")
  }

  /// The link list runs before the copy list and the hook, and points at
  /// the repository's own file rather than duplicating it.
  @Test func listedFilesAreLinkedInBeforeTheCopyListAndTheHook() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try FileManager.default.createDirectory(
      at: harness.project.path.appendingPathComponent("node_modules"),
      withIntermediateDirectories: true)
    try plantEnvFile(harness)
    harness.model.setSettings(
      ProjectSettings(
        postCreateHook: "cp .env seen.txt", linkedPaths: "node_modules", copiedPaths: ".env"),
      for: harness.project)

    await harness.model.createWorktree(
      branch: "linked", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "linked"))
    // Read before the setup task has had the actor: the stage the pane
    // opens on is the link list, whatever else the project has.
    #expect(harness.model.worktreeOperations[created.id]?.stage == .linkingFiles)
    await harness.model.stageHandles.setup(of: created.id)?.value

    #expect(harness.model.presentedError == nil)
    #expect(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: created.path.appendingPathComponent("node_modules").path)
        == harness.project.path.appendingPathComponent("node_modules").path)
    #expect(
      try String(contentsOf: created.path.appendingPathComponent("seen.txt"), encoding: .utf8)
        == "SECRET=1", "and the copy list, then the hook, ran after it")
    #expect(harness.model.worktreeOperations[created.id] == nil, "every stage ended")
  }

  /// The promise a failed stage makes: the list after it and the hook
  /// after that do not run, so one clear failure does not become two.
  @Test func aFailedLinkListStopsTheCopyListAndTheHookAndHoldsTheFirstTab() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.divertARepositoryPathWithASymlink()
    try plantEnvFile(harness)
    try harness.writeSharedSettings(
      #"""
      { "linkedPaths": "link/key", "copiedPaths": ".env",
        "postCreateHook": "echo ran > hook.txt" }
      """#)
    await harness.model.refreshWorktrees(of: harness.project)
    try harness.answerTrust(true)

    await harness.model.createWorktree(
      branch: "stuck", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "stuck"))
    await harness.model.stageHandles.setup(of: created.id)?.value

    #expect(harness.model.presentedError == nil, "not an alert the sheet's dismissal would drop")
    let shown = try #require(harness.model.worktreeOperations[created.id])
    #expect(shown.title == "Some files were not linked into the worktree")
    #expect(shown.failure?.contains("link/key") == true)
    let manager = FileManager.default
    #expect(
      !manager.fileExists(atPath: created.path.appendingPathComponent(".env").path),
      "the copy list after it did not run")
    #expect(!manager.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path))
    #expect(harness.model.workspace.tabs(in: created.id).isEmpty, "held back until dismissed")

    harness.model.dismissOperationFailure(of: created)
    #expect(harness.model.worktreeOperations[created.id] == nil)
    #expect(
      !harness.model.workspace.tabs(in: created.id).isEmpty, "and Dismiss hands the worktree over")
  }

  /// A link list reads the reader's own checkout, so it waits for the same
  /// yes the hook beside it waits for, and one answer covers the file.
  @Test func aRepositorysLinkListWaitsForTheTrustQuestionLikeItsHooks() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try FileManager.default.createDirectory(
      at: harness.project.path.appendingPathComponent("node_modules"),
      withIntermediateDirectories: true)
    try harness.writeSharedSettings(
      #"{ "linkedPaths": "node_modules", "postCreateHook": "echo ran > hook.txt" }"#)
    await harness.model.refreshWorktrees(of: harness.project)

    await harness.model.createWorktree(
      branch: "shared", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "shared"))
    await harness.model.stageHandles.setup(of: created.id)?.value

    #expect(
      !FileManager.default.fileExists(
        atPath: created.path.appendingPathComponent("node_modules").path),
      "untrusted, so the list did not apply")
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and neither did the hook beside it in the same file")
    #expect(harness.model.worktreeOperations[created.id] == nil, "the link stage ended")

    try harness.answerTrust(true)
    await harness.model.createWorktree(
      branch: "trusted", basedOn: nil, createsBranch: true, in: harness.project)
    let second = try #require(harness.worktree(onBranch: "trusted"))
    await harness.model.stageHandles.setup(of: second.id)?.value

    #expect(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: second.path.appendingPathComponent("node_modules").path)
        == harness.project.path.appendingPathComponent("node_modules").path,
      "and once trusted the link list applies")
  }

  /// A file list has no process to signal, so Cancel is asked per path. The
  /// worktree is handed over the way a stopped hook hands it over.
  @Test func cancelOnAFileListEndsTheSetupAndHandsTheWorktreeOver() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try plantEnvFile(harness)
    harness.model.setSettings(
      ProjectSettings(postCreateHook: "echo ran > hook.txt", copiedPaths: ".env"),
      for: harness.project)

    await harness.model.createWorktree(
      branch: "halted", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "halted"))
    // Before the setup task has had the actor: the stage's handle is made
    // early so the stop lands at its first path, not in a race with it.
    #expect(harness.model.worktreeOperations[created.id]?.stage == .copyingFiles)
    harness.model.cancelStage(of: created)
    await harness.model.stageHandles.setup(of: created.id)?.value

    #expect(harness.model.presentedError == nil, "a stop is the user's own doing, not a failure")
    #expect(
      harness.model.worktreeOperations[created.id] == nil, "the stage ended rather than failing")
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent(".env").path))
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and the hook after it did not run")
    #expect(
      !harness.model.workspace.tabs(in: created.id).isEmpty, "the worktree is the user's to use")
  }

  /// A copy list reads the reader's own checkout, git-ignored files
  /// included, so like the hooks beside it in the file it waits.
  @Test func aRepositorysCopyListWaitsForTheTrustQuestionLikeItsHooks() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try plantEnvFile(harness)
    try harness.writeSharedSettings(
      #"{ "copiedPaths": ".env", "postCreateHook": "echo ran > hook.txt" }"#)
    await harness.model.refreshWorktrees(of: harness.project)

    await harness.model.createWorktree(
      branch: "shared", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "shared"))
    await harness.model.stageHandles.setup(of: created.id)?.value

    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent(".env").path),
      "untrusted, so the copy list did not apply")
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and neither did the hook beside it in the same file")
    #expect(harness.model.worktreeOperations[created.id] == nil, "the copy stage ended")
    #expect(
      !harness.model.workspace.tabs(in: created.id).isEmpty,
      "and the first terminal opened once it had, with no hook to wait for")
  }

  /// The alert would be raised as the sheet went away, which is where one
  /// gets dropped, so a failed copy goes to the pane and holds the tab.
  @Test func aFailedCopyShowsInThePaneAndKeepsThePostCreateHookFromRunning() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.divertARepositoryPathWithASymlink()
    try harness.writeSharedSettings(
      #"{ "copiedPaths": "link/key", "postCreateHook": "echo ran > hook.txt" }"#)
    await harness.model.refreshWorktrees(of: harness.project)
    try harness.answerTrust(true)

    await harness.model.createWorktree(
      branch: "escaped", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "escaped"))
    await harness.model.stageHandles.setup(of: created.id)?.value

    #expect(harness.model.presentedError == nil, "not an alert the sheet's dismissal would drop")
    let shown = try #require(harness.model.worktreeOperations[created.id])
    #expect(shown.title == "Some files were not copied into the worktree")
    #expect(shown.failure?.contains("link/key") == true)
    #expect(
      !FileManager.default.fileExists(
        atPath: created.path.appendingPathComponent("hook.txt").path),
      "the hook did not run")
    #expect(harness.model.workspace.tabs(in: created.id).isEmpty, "held back until dismissed")

    harness.model.dismissOperationFailure(of: created)
    #expect(harness.model.worktreeOperations[created.id] == nil)
  }

  /// A list the user typed is theirs, `RepositoryContainment` holding only
  /// what a repository ships; an entry reaching out is skipped, not refused.
  @Test func skippedEntriesAreStillNamedWhenALaterListFails() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let locked = harness.project.path.appendingPathComponent("locked.txt")
    try "x".write(to: locked, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)
    defer {
      try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path)
    }
    harness.model.setSettings(
      ProjectSettings(linkedPaths: "~/.aws.json", copiedPaths: "locked.txt"), for: harness.project)

    await harness.model.createWorktree(
      branch: "mine", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "mine"))
    await harness.model.stageHandles.setup(of: created.id)?.value

    let shown = try #require(harness.model.worktreeOperations[created.id])
    #expect(!shown.isRunning, "the copy failed")
    #expect(shown.failure?.contains("locked.txt") == true)
    #expect(shown.failure?.contains("~/.aws.json") == true, "on the one failure that is shown")
    #expect(harness.model.presentedError == nil, "not a second message racing it for the one alert")
  }

  @Test func aCancelledListStillNamesTheEntriesItSkippedBeforeTheStop() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try plantEnvFile(harness)
    harness.model.setSettings(
      ProjectSettings(copiedPaths: "~/.aws.json\n.env"), for: harness.project)

    await harness.model.createWorktree(
      branch: "mine", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "mine"))
    harness.model.cancelStage(of: created)
    await harness.model.stageHandles.setup(of: created.id)?.value

    #expect(
      harness.model.worktreeOperations[created.id] == nil, "the stage ended rather than failing")
    #expect(harness.model.presentedError?.message.contains("~/.aws.json") == true)
  }

  @Test func aPathTheUserListedThemselvesDoesNotStopTheStagesAfterIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try plantEnvFile(harness)
    harness.model.setSettings(
      ProjectSettings(postCreateHook: "echo ran > hook.txt", copiedPaths: "~/.aws.json\n.env"),
      for: harness.project)

    await harness.model.createWorktree(
      branch: "mine", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "mine"))
    await harness.model.stageHandles.setup(of: created.id)?.value

    #expect(harness.model.worktreeOperations[created.id] == nil, "every stage ended")
    let manager = FileManager.default
    #expect(manager.fileExists(atPath: created.path.appendingPathComponent(".env").path))
    #expect(
      manager.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and the hook after the list ran")
    #expect(harness.model.presentedError?.message.contains("~/.aws.json") == true)
  }

  /// The user's own list replaces the repository's whole, so what is placed
  /// is theirs and is not held to the checkout, file on disk or not.
  @Test func theUsersOwnListOverridingTheRepositorysIsStillTheirs() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let secret = harness.root.appendingPathComponent("secrets.txt")
    try "SECRET=1".write(to: secret, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: harness.project.path.appendingPathComponent(".env"), withDestinationURL: secret)
    try harness.writeSharedSettings(#"{ "copiedPaths": "vendor" }"#)
    await harness.model.refreshWorktrees(of: harness.project)
    harness.model.setSettings(
      harness.project.settings.with { $0.copiedPaths = ".env" }, for: harness.project)

    await harness.model.createWorktree(
      branch: "mine", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "mine"))
    await harness.model.stageHandles.setup(of: created.id)?.value

    #expect(
      harness.model.worktreeOperations[created.id] == nil, "the stage ended rather than failing")
    #expect(
      try String(contentsOf: created.path.appendingPathComponent(".env"), encoding: .utf8)
        == "SECRET=1", "and their symlinked file was placed")
  }
}
