import Foundation
import MultishellCore
import MultishellGitKit
import Observation
import Testing

@testable import MultishellAppCore

/// The model on real git, a fake engine and a fake watcher: what the sidebar
/// flows do from a click to the shells and the repository, in a throwaway
/// repository under the temp directory.
@MainActor
private struct GitHarness {
  let root: URL
  let git: GitRunner
  let model: AppModel<FakeSurface>
  let store: WorkspaceStore
  let engine = FakeEngine()
  let watcher = FakeWatcher()
  let platform = FakePlatform()

  init() async throws {
    git = try GitRunner()
    root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-appgit-\(UUID().uuidString)", isDirectory: true)
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    _ = try await git.run(["init", "--initial-branch=main"], in: repository)
    _ = try await git.run(["config", "user.email", "tests@multishell.local"], in: repository)
    _ = try await git.run(["config", "user.name", "Multishell Tests"], in: repository)
    try "hello\n".write(
      to: repository.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    _ = try await git.run(["add", "."], in: repository)
    _ = try await git.run(["commit", "-q", "-m", "initial"], in: repository)

    store = WorkspaceStore(
      snapshot: WorkspaceSnapshot(fileURL: root.appendingPathComponent("state.json")))
    let engine = self.engine
    model = AppModel(
      store: store,
      host: MultiEngineHost(engine: .ghostty) { _ in engine },
      worktrees: WorktreeCoordinator(service: WorktreeService(git: git)),
      watcher: watcher, platform: platform)
    await model.addProject(at: repository)
  }

  /// Waits for the removal that `requestRemoval` or a dialog started, up to
  /// a few seconds, by watching the operation entry.
  func awaitOperationEnd(on id: Worktree.ID) async {
    for _ in 0..<200 where model.worktreeOperations[id]?.isRunning == true {
      try? await Task.sleep(for: .milliseconds(50))
    }
  }

  var project: Project { model.workspace.projects[0] }

  /// A second model on the same store, with a shell script standing in for
  /// git. `$SCRATCH` is the harness root; every call is appended to
  /// `$SCRATCH/calls`.
  func modelOnFakeGit(_ body: String) throws -> AppModel<FakeSurface> {
    let script = root.appendingPathComponent("fake-git-\(UUID().uuidString)")
    try """
    #!/bin/sh
    SCRATCH="\(root.path)"
    echo "$*" >> "$SCRATCH/calls"
    \(body)
    """.write(to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
    let engine = self.engine
    let model = AppModel(
      store: store,
      host: MultiEngineHost(engine: .ghostty) { _ in engine },
      worktrees: WorktreeCoordinator(
        service: WorktreeService(git: try GitRunner(executable: script))),
      watcher: watcher)
    model.presentedError = nil
    return model
  }

  func gitCalls() -> [String] {
    (try? String(contentsOf: root.appendingPathComponent("calls"), encoding: .utf8))?
      .split(whereSeparator: \.isNewline).map(String.init) ?? []
  }

  func worktree(onBranch branch: String) -> Worktree? {
    model.workspace.worktrees(of: project.id).first { $0.branch == branch }
  }

  func tearDown() {
    try? FileManager.default.removeItem(at: root)
  }
}

@Suite(.serialized) @MainActor
struct AppModelGitTests {
  @Test func addingARepositoryDiscoversItsMainWorktreeAndArmsTheWatcher() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }

    #expect(h.model.workspace.projects.count == 1)
    #expect(h.model.presentedError == nil)
    let worktrees = h.model.workspace.worktrees(of: h.project.id)
    #expect(worktrees.map(\.branch) == ["main"])
    #expect(worktrees[0].isPrimary)
    #expect(h.watcher.watched.map(\.lastPathComponent) == [".git"])
  }

  @Test func addingASubdirectoryIsTheSameProject() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let sources = h.project.path.appendingPathComponent("Sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)

    await h.model.addProject(at: sources)

    #expect(h.model.workspace.projects.count == 1, "identity is the main worktree's path")
  }

  @Test func addingSomethingThatIsNotARepositoryIsRefused() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }

    await h.model.addProject(at: h.root)

    #expect(h.model.workspace.projects.count == 1)
    #expect(h.model.presentedError?.title == "Not a git repository")
  }

  @Test func creatingAWorktreeSelectsItOpensAShellAndWatchesItsRecords() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }

    await h.model.createWorktree(
      branch: "feat/tabs", basedOn: nil, createBranch: true, in: h.project)

    let created = try #require(h.worktree(onBranch: "feat/tabs"))
    #expect(h.model.presentedError == nil)
    #expect(created.path.lastPathComponent == "feat-tabs")
    #expect(FileManager.default.fileExists(atPath: created.path.path))
    #expect(h.model.workspace.selectedWorktreeID == created.id)
    #expect(h.model.workspace.tabs(in: created.id).count == 1)
    #expect(h.model.liveTerminalCount == 1)
    #expect(h.engine.openSessionIDs == Set(h.model.workspace.sessions(in: created.id).map(\.id)))
    #expect(
      h.watcher.watched.map(\.lastPathComponent).sorted() == ["feat-tabs", "worktrees"],
      "the linked worktree's own record directory is watched for branch switches")
  }

  @Test func aFailingHookStillShowsAndSelectsTheWorktree() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "exit 3"), for: h.project)

    await h.model.createWorktree(branch: "hooked", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "hooked"))
    #expect(h.model.workspace.selectedWorktreeID == created.id, "shown before the hook ends")
    h.model.presentedError = nil
    await h.model.postCreateHooks[created.id]?.value

    // In the pane, not an alert: an alert raised while the sheet is still
    // going away is lost, and one raised later lands over other work.
    #expect(h.model.presentedError == nil)
    let failed = try #require(h.model.worktreeOperations[created.id])
    #expect(!failed.isRunning && failed.step == .postCreateHook)
    #expect(failed.title == "The post-create hook failed")
    #expect(h.model.isBusy(created.id), "held until dismissed")
    #expect(h.model.liveTerminalCount == 0)

    h.model.dismissOperationFailure(of: created)
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(h.model.workspace.selectedWorktreeID == created.id)
    #expect(h.model.liveTerminalCount == 1, "dismissing hands over to a shell")
  }

  @Test func aFailedHooksOutputIsWhatThePaneShows() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "echo installing\necho npm said no >&2\nexit 1"),
      for: h.project)

    await h.model.createWorktree(branch: "loud", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "loud"))
    await h.model.postCreateHooks[created.id]?.value

    #expect(
      h.model.worktreeOperations[created.id]?.failure
        == "installing\nnpm said no\n\nExited with status 1.",
      "what the hook printed on either stream, then its status, and no rc noise")
  }

  /// The reason the hook runs apart from the sheet: `npm install` in a
  /// post-create hook used to hold the sheet, and the whole app, for as
  /// long as it took.
  @Test func aSlowPostCreateHookReturnsAtOnceShowsItsProgressAndHoldsTheFirstTab() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 3"), for: h.project)

    let started = ContinuousClock.now
    await h.model.createWorktree(branch: "slow", basedOn: nil, createBranch: true, in: h.project)
    let returned = ContinuousClock.now - started

    let created = try #require(h.worktree(onBranch: "slow"))
    // Two git spawns and a refresh: well under a second here, and a slow
    // runner still cannot stretch it to the hook's three.
    #expect(returned < .seconds(2), "came back before the hook could: \(returned)")
    #expect(h.model.workspace.selectedWorktreeID == created.id)
    #expect(h.model.worktreeOperations[created.id]?.step == .postCreateHook)
    #expect(h.model.isBusy(created.id))
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "no shell until the hook is done")
    #expect(h.model.liveTerminalCount == 0)

    h.model.newTab()
    h.model.newShellTab()
    h.model.select(created)
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "nothing starts a shell meanwhile")
    h.model.requestRemoval(of: created)
    #expect(h.model.pendingRemoval == nil, "and nothing removes it meanwhile")

    await h.model.postCreateHooks[created.id]?.value

    #expect(h.model.presentedError == nil)
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(h.model.workspace.tabs(in: created.id).count == 1, "the held-back first tab")
    #expect(h.model.liveTerminalCount == 1)
  }

  @Test func aHookThatEndsWhileAnotherWorktreeIsShownLeavesTheFirstTabToTheNextVisit()
    async throws
  {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 0.5"), for: h.project)
    await h.model.createWorktree(branch: "later", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "later"))
    let main = try #require(h.worktree(onBranch: "main"))
    h.model.select(main)

    await h.model.postCreateHooks[created.id]?.value

    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "not opened behind the user's back")
    #expect(h.model.workspace.selectedWorktreeID == main.id)
    h.model.select(created)
    #expect(h.model.workspace.tabs(in: created.id).count == 1)
  }

  @Test func removalShowsItsStageInThePaneUntilItEnds() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "going", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "going"))
    h.model.updateSettings(ProjectSettings(preDeleteHook: "sleep 1"), for: h.project)
    #expect(h.model.liveTerminalCount == 1)

    let removal = Task { await h.model.removeWorktree(worktree) }
    var seen: Set<WorktreeOperation.Step> = []
    let deadline = ContinuousClock.now + .seconds(15)
    while ContinuousClock.now < deadline, !seen.contains(.removingWorktree) {
      if let step = h.model.worktreeOperations[worktree.id]?.step { seen.insert(step) }
      try await Task.sleep(for: .milliseconds(20))
    }
    await removal.value

    #expect(seen.contains(.preDeleteHook), "the hook was named while it ran: \(seen)")
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(h.worktree(onBranch: "going") == nil)
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func aFailingPreCreateHookCreatesNothingAndSelectsNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(preCreateHook: "echo no >&2\nexit 3"), for: h.project)

    await h.model.createWorktree(branch: "refused", basedOn: nil, createBranch: true, in: h.project)

    #expect(h.worktree(onBranch: "refused") == nil)
    #expect(h.model.presentedError?.title == "Worktree not created: its pre-create hook failed")
    #expect(
      h.model.presentedError?.message == "no\n\nExited with status 3.",
      "the hook's line and its status, and no rc noise")
    #expect(h.model.workspace.selectedWorktreeID == nil)
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func aFailingPreDeleteHookLeavesTheWorktreeAndItsShells() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "kept", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "kept"))
    h.model.updateSettings(ProjectSettings(preDeleteHook: "exit 1"), for: h.project)

    h.model.presentedError = nil
    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil, "the veto is shown in the pane, with no Remove Anyway")
    let refused = try #require(h.model.worktreeOperations[worktree.id])
    #expect(!refused.isRunning && refused.step == .preDeleteHook)
    #expect(refused.title == "The pre-delete hook refused the removal")
    #expect(h.worktree(onBranch: "kept") != nil)
    #expect(h.model.liveTerminalCount == 1, "the shells were never closed")
    #expect(FileManager.default.fileExists(atPath: worktree.path.path))

    h.model.dismissOperationFailure(of: worktree)
    #expect(h.model.worktreeOperations.isEmpty, "the pane shows the terminals again")
    #expect(h.model.liveTerminalCount == 1)
  }

  @Test func hooksRunThroughTheProjectsShellOverride() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setDefaultShell("/bin/zsh")
    h.model.updateSettings(
      ProjectSettings(
        postCreateHook: "printf '%s' \"$BASH_VERSION\" > shell.txt", defaultShell: "/bin/bash"),
      for: h.project)

    await h.model.createWorktree(branch: "bashed", basedOn: nil, createBranch: true, in: h.project)

    let created = try #require(h.worktree(onBranch: "bashed"))
    await h.model.postCreateHooks[created.id]?.value
    let version = try String(
      contentsOf: created.path.appendingPathComponent("shell.txt"), encoding: .utf8)
    #expect(!version.isEmpty, "the project's bash, not the global zsh")
  }

  @Test func aHookThatLeavesABackgroundProcessDoesNotHangTheCreate() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 30 &"), for: h.project)

    let started = ContinuousClock.now
    await h.model.createWorktree(branch: "served", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "served"))
    await h.model.postCreateHooks[created.id]?.value
    let elapsed = ContinuousClock.now - started

    #expect(h.model.presentedError == nil)
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(elapsed < .seconds(10), "waited on the hook's child: \(elapsed)")
  }

  @Test func removingAWorktreeClosesItsShellsAndDropsItsTabs() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "gone", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "gone"))
    h.model.newTab()
    #expect(h.model.liveTerminalCount == 2)

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "gone") == nil)
    #expect(h.model.workspace.tabs(in: worktree.id).isEmpty)
    #expect(h.model.workspace.sessions(in: worktree.id).isEmpty)
    #expect(h.engine.closed.count == 2)
    #expect(h.model.liveTerminalCount == 0)
    #expect(h.model.workspace.selectedWorktreeID == nil)
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
    #expect(
      h.watcher.watched.map(\.lastPathComponent) == [".git"],
      "git deletes the worktrees folder with its last entry, so the watch falls back")
  }

  @Test func aRemovedWorktreeGoesToTheTrashWithItsUncommittedWork() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "dirty", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "dirty"))
    try "uncommitted\n".write(
      to: worktree.path.appendingPathComponent("work.txt"), atomically: true, encoding: .utf8)
    await h.model.refreshStatuses()
    let pending = PendingWorktreeRemoval(worktree: worktree, branch: .decided(deletes: false))
    #expect(
      pending.message(warning: h.model.removalWarning(for: worktree))
        .contains("1 changed file, kept in the Trash"))

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.platform.trashed == [worktree.path])
    #expect(h.worktree(onBranch: "dirty") == nil, "pruned from git and the sidebar")
    #expect(
      FileManager.default.fileExists(
        atPath: h.platform.trash!.appendingPathComponent("dirty/work.txt").path))
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func removingWithTheBranchDeletesItAndAnUnmergedOneOffersTheForcedForm() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "merged", basedOn: nil, createBranch: true, in: h.project)
    let merged = try #require(h.worktree(onBranch: "merged"))

    await h.model.removeWorktree(merged, deletingBranch: true)

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "merged") == nil)
    let branches = try await h.git.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: h.project.path)
    #expect(!branches.contains("merged"))

    await h.model.createWorktree(branch: "ahead", basedOn: nil, createBranch: true, in: h.project)
    let ahead = try #require(h.worktree(onBranch: "ahead"))
    try "work\n".write(
      to: ahead.path.appendingPathComponent("w.txt"), atomically: true, encoding: .utf8)
    _ = try await h.git.run(["add", "."], in: ahead.path)
    _ = try await h.git.run(["commit", "-q", "-m", "ahead"], in: ahead.path)

    await h.model.removeWorktree(ahead, deletingBranch: true)

    let refused = try #require(h.model.presentedError)
    #expect(refused.title == "Worktree removed, but branch ahead was not deleted")
    #expect(refused.retryLabel == "Delete Branch Anyway")
    #expect(h.worktree(onBranch: "ahead") == nil, "the worktree itself went")
    #expect(h.model.liveTerminalCount == 0)

    await refused.retry?()

    let after = try await h.git.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: h.project.path)
    #expect(!after.contains("ahead"))
  }

  @Test func aFailingPostDeleteHookKeepsTheBranchAndSaysSo() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "hooked", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "hooked"))
    h.model.updateSettings(ProjectSettings(postDeleteHook: "exit 2"), for: h.project)

    await h.model.removeWorktree(worktree, deletingBranch: true)

    #expect(h.model.presentedError?.title == "Worktree removed, but its hook failed")
    #expect(h.model.presentedError?.message.hasSuffix("The branch hooked was kept.") == true)
    #expect(h.worktree(onBranch: "hooked") == nil)
    let branches = try await h.git.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: h.project.path)
    #expect(branches.contains("hooked"), "a hook that pushes would have wanted it there")
  }

  @Test func theSheetSeesThePreCreateHookAndTheAddThenNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(
      ProjectSettings(preCreateHook: "sleep 1", postCreateHook: "true"), for: h.project)

    let create = Task {
      await h.model.createWorktree(
        branch: "stepped", basedOn: nil, createBranch: true, in: h.project)
    }
    var seen: Set<WorktreeCreationStep> = []
    let deadline = ContinuousClock.now + .seconds(15)
    while ContinuousClock.now < deadline, !seen.contains(.addingWorktree) {
      if let step = h.model.worktreeCreationStep { seen.insert(step) }
      try await Task.sleep(for: .milliseconds(20))
    }
    await create.value

    #expect(seen.contains(.preCreateHook), "the sheet could name the hook it waited on: \(seen)")
    #expect(!seen.contains(.postCreateHook), "the post hook runs after the sheet has gone")
    #expect(h.model.worktreeCreationStep == nil, "cleared once the sheet's part is over")
    let created = try #require(h.worktree(onBranch: "stepped"))
    await h.model.postCreateHooks[created.id]?.value
  }

  @Test func aWorktreeAddedOutsideTheAppIsFoundByTheWatcherTick() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let outside = h.root.appendingPathComponent("outside", isDirectory: true)
    _ = try await h.git.run(
      ["worktree", "add", "-q", "-b", "outside", outside.path], in: h.project.path)

    await h.model.refreshWorktreesIfRecordsChanged()

    #expect(h.worktree(onBranch: "outside") != nil)
    #expect(h.watcher.watched.map(\.lastPathComponent).sorted() == ["outside", "worktrees"])
  }

  @Test func aBranchSwitchInTheMainWorktreeIsCaughtByTheStatusPoll() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    _ = try await h.git.run(["checkout", "-q", "-b", "elsewhere"], in: h.project.path)
    #expect(h.worktree(onBranch: "main") != nil, "nothing has looked yet")

    await h.model.refreshStatuses()

    #expect(h.worktree(onBranch: "elsewhere") != nil)
    #expect(h.worktree(onBranch: "main") == nil)
    let statuses = h.model.statuses
    #expect(statuses.count == 1 && statuses.values.first?.branch == "elsewhere")
  }

  @Test func aRefreshLandingAfterTheProjectWasRemovedLeavesNoTrace() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    #expect(h.model.worktreeRecords[project.id] != nil)

    h.model.removeProject(project)
    await h.model.refresh(project)

    #expect(h.model.workspace.projects.isEmpty)
    #expect(h.model.workspace.worktrees.isEmpty)
    #expect(h.model.worktreeRecords[project.id] == nil)
    #expect(h.model.commonGitDirectories[project.id] == nil)
    #expect(h.model.missingProjects.isEmpty)
  }

  @Test func aRepositoryGitCanNoLongerReadIsReportedOnceThenDimmed() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    try FileManager.default.removeItem(at: project.path.appendingPathComponent(".git"))

    await h.model.refresh(project)
    let first = try #require(h.model.presentedError)
    #expect(first.title.hasPrefix("git worktree list failed"))
    #expect(h.model.missingProjects == [project.id])

    h.model.presentedError = nil
    await h.model.refreshWorktreesIfRecordsChanged()
    await h.model.refresh(project)

    #expect(h.model.presentedError == nil, "the same failure on every tick is one alert, not many")
    #expect(h.model.workspace.projects.count == 1)
  }

  /// What the descriptor limit used to produce: git "succeeds" and lists
  /// nothing. The project must keep what it had and say something went wrong.
  @Test func aRefreshWhereGitListsNothingKeepsTheWorktreesAndTheirTabs() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    h.model.select(h.worktree(onBranch: "main")!)
    #expect(h.model.liveTerminalCount == 1)

    let muted = try h.modelOnFakeGit("exit 0")

    await muted.refresh(project)

    #expect(muted.workspace.worktrees(of: project.id).count == 1, "nothing was dropped")
    #expect(muted.workspace.tabs.count == 1)
    #expect(muted.presentedError != nil)
    #expect(muted.missingProjects == [project.id])
  }

  /// The watched directories also hold each worktree's `index`, which every
  /// `git status` rewrites, so most ticks mean nothing. A tick must read the
  /// record files and spawn git only when they differ from the last refresh.
  @Test func aTickWithUnchangedRecordsSpawnsNoGitAndAChangedHEADDoes() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let repository = h.project.path.path
    let counting = try h.modelOnFakeGit(
      """
      case "$1 $2" in
        "rev-parse --path-format=absolute") printf '%s/.git\\n' "\(repository)" ;;
        "worktree list") printf 'worktree %s\\nHEAD 1111111\\nbranch refs/heads/main\\n' "\(repository)" ;;
      esac
      """)
    func listings() -> Int { h.gitCalls().filter { $0.hasPrefix("worktree list") }.count }

    await counting.refreshWorktreesIfRecordsChanged()
    #expect(listings() == 1, "no records yet, so a full refresh")

    await counting.refreshWorktreesIfRecordsChanged()
    await counting.refreshWorktreesIfRecordsChanged()
    #expect(listings() == 1, "nothing changed, so nothing was spawned")
    #expect(
      h.gitCalls().filter { $0.hasPrefix("rev-parse") }.count == 1, "the common dir is cached")

    _ = try await h.git.run(["checkout", "-q", "-b", "moved"], in: h.project.path)
    await counting.refreshWorktreesIfRecordsChanged()
    #expect(listings() == 2, "HEAD changed, so git was asked again")
  }

  @Test func anExplicitRefreshReportsAFailureAlreadyShown() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    try FileManager.default.removeItem(at: project.path.appendingPathComponent(".git"))
    await h.model.refresh(project)
    #expect(h.model.presentedError != nil)
    h.model.presentedError = nil
    await h.model.refresh(project)
    #expect(h.model.presentedError == nil, "a tick stays quiet")

    await h.model.refreshRequested(project)

    #expect(h.model.presentedError != nil, "the user asked, so the answer is shown again")
    #expect(h.model.missingProjects == [project.id])
  }

  /// A status read can fail for a moment: a lock, a slow disk, a directory
  /// mid-rename. The badge must not blink off for five seconds each time.
  @Test func aFailedStatusReadKeepsTheLastBadgeUntilTheNextGoodOne() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let flaky = try h.modelOnFakeGit(
      """
      while [ "${1#--}" != "$1" ]; do shift; done
      case "$1" in
        status) if [ -e "$SCRATCH/fail" ]; then exit 128; fi
                printf '## main\\n M a.txt\\n' ;;
      esac
      """)
    let main = try #require(h.worktree(onBranch: "main"))

    await flaky.refreshStatuses()
    #expect(flaky.statuses[main.id]?.changedFiles == 1)

    try Data().write(to: h.root.appendingPathComponent("fail"))
    await flaky.refreshStatuses()
    #expect(flaky.statuses[main.id]?.changedFiles == 1, "kept through the failed read")

    h.store.replaceWorktrees([], forProject: h.project.id)
    await flaky.refreshStatuses()
    #expect(flaky.statuses.isEmpty, "a worktree that is gone loses its badge")
  }

  @Test func aProjectWhoseDirectoryVanishesIsDimmedNotDropped() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    h.model.select(h.worktree(onBranch: "main")!)
    try FileManager.default.removeItem(at: project.path)

    await h.model.refresh(project)

    #expect(h.model.workspace.projects.count == 1, "an unmounted drive must not delete the setup")
    #expect(h.model.missingProjects == [project.id])
    #expect(h.model.workspace.worktrees(of: project.id).count == 1, "kept as last seen")
  }

  @Test func aBranchThatLandsGetsItsBadgeAndTheMainWorktreeNeverDoes() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)
    let feat = try #require(h.worktree(onBranch: "feat"))
    let main = try #require(h.worktree(onBranch: "main"))

    // Cut from the trunk's own tip and not yet written in: an ancestor of
    // main from the moment it existed, and not merged.
    await h.model.refreshMergeStates()
    #expect(h.model.mergeState(of: feat) == .unmerged, "a worktree just made is not merged")

    _ = try await h.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    await h.model.refreshMergeStates()
    #expect(h.model.mergeState(of: feat) == .unmerged)
    #expect(h.model.mergeBase(of: h.project)?.ref == "main", "no remote, so the local branch")

    _ = try await h.git.run(["merge", "-q", "--no-ff", "-m", "merge", "feat"], in: h.project.path)
    await h.model.refreshMergeStates()

    #expect(h.model.mergeState(of: feat) == .merged(.ancestor, into: "main"))
    #expect(h.model.mergeState(of: main) == .unknown, "the trunk is not merged into itself")
    #expect(h.model.presentedError == nil)
  }

  /// The check runs on the status poll, so a pass that finds nothing moved
  /// must not touch the observable state: writing a dictionary entry back
  /// unchanged still tells every view watching it to draw again, and this
  /// would do that to the whole sidebar every five seconds.
  @Test func aPassThatChangesNothingDoesNotDisturbTheViews() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)
    await h.model.refreshMergeStates()

    let model = h.model
    let fired = Fired()
    withObservationTracking {
      _ = model.mergeStates
      _ = model.mergeBases
    } onChange: {
      fired.value = true
    }
    await h.model.refreshMergeStates()

    #expect(!fired.value, "nothing moved, so nothing to redraw")
  }

  /// A git call that failed is not an answer, and must not be recorded as
  /// one: the verdict it could not replace would then be pinned to the new
  /// tip and never asked about again.
  @Test func aFailedReadLeavesTheBranchToBeAskedAboutAgain() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)
    let feat = try #require(h.worktree(onBranch: "feat"))

    // Tip AAA, then BBB, and `branch --merged` fails on every pass after
    // the first: the branch moved, and nothing can say where it stands.
    let model = try h.modelOnFakeGit(
      """
      SEEN="$SCRATCH/passes"
      printf x >> "$SEEN"
      PASS=$(wc -c < "$SEEN" | tr -d ' ')
      case "$*" in
        for-each-ref*)
          if [ "$PASS" -le 2 ]; then TIP=AAA; else TIP=BBB; fi
          printf 'refs/heads/main\\tMMM\\t\\t\\nrefs/heads/feat\\t%s\\t\\t\\n' "$TIP" ;;
        branch\\ --merged*)
          if [ "$PASS" -le 2 ]; then echo main; else exit 128; fi ;;
        cherry*) echo '+ AAA' ;;
        *) exit 0 ;;
      esac
      """)

    await model.refreshMergeStates()
    #expect(model.mergeState(of: feat) == .unmerged, "a first answer, from a working git")

    await model.refreshMergeStates()
    let afterFailure = h.gitCalls().filter { $0.hasPrefix("branch --merged") }.count

    await model.refreshMergeStates()
    let afterRetry = h.gitCalls().filter { $0.hasPrefix("branch --merged") }.count
    #expect(afterRetry > afterFailure, "the failed pass must not settle the question")
  }

  /// A fetch waits on a network, so the sidebar has to say it is happening
  /// and a second click must not start another one.
  @Test func aFetchMarksItsProjectForAllOfItAndRefusesASecond() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let model = try h.modelOnFakeGit(
      """
      case "$*" in
        fetch*) sleep 1 ;;
        worktree\\ list*)
          printf 'worktree %s\\nHEAD abc\\nbranch refs/heads/main\\n\\n' "$SCRATCH/demo" ;;
        for-each-ref*) printf 'refs/heads/main\\tAAA\\t\\t\\n' ;;
        *) exit 0 ;;
      esac
      """)
    let project = h.project
    #expect(!model.isFetching(project))

    let running = Task { await model.fetch(project) }
    for _ in 0..<200 where !model.isFetching(project) { await Task.yield() }
    #expect(model.isFetching(project), "marked before it waits on anything")

    // The menu item is disabled by this, but a keyboard repeat or a second
    // window must not get past it either.
    await model.fetch(project)
    #expect(model.isFetching(project), "the first one is still running")

    await running.value
    #expect(!model.isFetching(project))
    #expect(
      h.gitCalls().filter { $0.hasPrefix("fetch") }.count == 1, "one fetch, not two")
    // The mark covers the re-reads too: they are what the user clicked for.
    #expect(h.gitCalls().contains { $0.hasPrefix("for-each-ref") })
  }

  /// The badge is on the status poll, so what it costs when nothing has
  /// moved is the ceiling on how often it may run.
  @Test func asecondPassAsksGitNothingAboutABranchThatHasNotMoved() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)

    let model = try h.modelOnFakeGit(
      """
      case "$*" in
        for-each-ref*) printf 'refs/heads/main\\tAAA\\t\\t\\nrefs/heads/feat\\tBBB\\t\\t\\n' ;;
        branch\\ --merged*) echo main ;;
        cherry*) echo '+ BBB' ;;
      esac
      """)

    await model.refreshMergeStates()
    let first = h.gitCalls()
    #expect(first.filter { $0.hasPrefix("branch --merged") }.count == 1)
    #expect(first.contains { $0.hasPrefix("cherry") })
    let feat = try #require(h.worktree(onBranch: "feat"))
    #expect(model.mergeState(of: feat) == .unmerged)

    await model.refreshMergeStates()
    let second = h.gitCalls().dropFirst(first.count)

    #expect(!second.contains { $0.hasPrefix("branch --merged") || $0.hasPrefix("cherry") })
    #expect(second.count == 1, "the one read that says nothing moved, and nothing else")
    #expect(model.mergeState(of: feat) == .unmerged)
  }
}

@Suite(.serialized) @MainActor
struct NewWorktreeSheetLoadTests {
  /// The sheet's load, step for step, against a repository with spare
  /// branches: the existing-branch list must offer the ones not checked out.
  @Test func theExistingBranchListOffersTheUncheckedOutLocalBranches() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    _ = try await h.git.run(["branch", "release"], in: h.project.path)
    _ = try await h.git.run(["branch", "spike"], in: h.project.path)
    h.model.requestNewWorktree(in: h.project)
    let request = try #require(h.model.newWorktreeRequest)

    var draft = NewWorktreeDraft(projectID: request.projectID)
    draft.beginLoading()
    let project = try #require(h.model.workspace.project(request.projectID!))
    let hasCommits = await h.model.hasCommits(project)
    let (branches, remoteBranches) = await h.model.branches(of: project)
    let current = await h.model.currentBranch(of: project)
    let checkedOut = Set(h.model.workspace.worktrees(of: project.id).compactMap(\.branch))
    draft.finishLoading(
      project.id, hasCommits: hasCommits, branches: branches, remoteBranches: remoteBranches,
      currentBranch: current, checkedOut: checkedOut)

    #expect(draft.availableBranches(checkedOut: checkedOut) == ["release", "spike"])
    draft.createBranch = false
    draft.modeChanged(checkedOut: checkedOut)
    #expect(draft.branch == "release")
    #expect(draft.canCreate(checkedOut: checkedOut))
  }
}

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
    await h.model.postCreateHooks[created.id]?.value

    #expect(ContinuousClock.now - started < .seconds(10))
    let failed = try #require(h.model.worktreeOperations[created.id])
    #expect(failed.timedOut && failed.title == "The post-create hook did not finish")
    #expect(failed.failure == "installing\n\nStopped after 1 second, the hook timeout.")
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "held back until dismissed")
  }

  @Test func stopHookEndsAPostCreateHookAndHandsTheWorktreeOver() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 30"), for: h.project)

    await h.model.createWorktree(branch: "stopped", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "stopped"))
    #expect(h.model.worktreeOperations[created.id]?.isRunning == true)
    h.model.stopHook(of: created)
    await h.model.postCreateHooks[created.id]?.value

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
    #expect(h.model.postCreateHooks[a.id] == nil)
    #expect(!FileManager.default.fileExists(atPath: a.path.appendingPathComponent("hook.txt").path))

    h.model.decideSharedHooks(pending, trusted: true)
    #expect(h.model.pendingSharedHooksTrust == nil)
    #expect(h.model.trustsSharedHooks(of: h.project))
    await h.model.createWorktree(branch: "b", basedOn: nil, createBranch: true, in: h.project)
    let b = try #require(h.worktree(onBranch: "team/b"))
    await h.model.postCreateHooks[b.id]?.value
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
      ProjectSettings(branchPrefix: "team/", postCreateHook: "npm ci", iconGlyph: "🚀", iconTint: 3),
      for: h.project)

    h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.branchPrefix == "team/" && written.postCreateHook == "npm ci")
    #expect(written.iconGlyph == "🚀" && written.iconTint == 3)
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

/// A box for `withObservationTracking`, whose callback may not capture a
/// mutable local.
private final class Fired: @unchecked Sendable {
  var value = false
}
