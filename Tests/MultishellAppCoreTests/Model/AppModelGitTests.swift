import Foundation
import MultishellCore
import MultishellGitKit
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore

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

  @Test func theStatusPollSkipsTheWorktreesOfAMissingProject() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let fake = try h.modelOnFakeGit("exit 0")
    let project = fake.workspace.projects[0]

    fake.missingProjects.insert(project.id)
    await fake.refreshStatuses()
    #expect(!h.gitCalls().contains { $0.contains("status") }, "its directory is gone")

    fake.missingProjects.remove(project.id)
    await fake.refreshStatuses()
    #expect(h.gitCalls().contains { $0.contains("status") })
  }

  @Test func aWorktreeWhoseStatusIsSlowIsNotAskedAgainOnTheNextTick() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let fake = try h.modelOnFakeGit("case \"$*\" in *status*) sleep 0.6;; esac; exit 0")
    fake.statusReads.pace = .standard

    await fake.refreshStatuses()
    await fake.refreshStatuses()

    #expect(
      h.gitCalls().filter { $0.contains("status") }.count == 1,
      "a read that took 0.6 s is not due again for 6 s")
  }

  @Test func changingTheGitStatusIndicatorReadsEveryBadgeAtOnce() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.statusReads.pace = .standard

    await h.model.refreshStatuses()
    #expect(!h.model.statusReads.isEmpty, "a read the pace would hold the next one back for")

    h.model.setGitStatusIndicator(.stagedOnly)
    #expect(h.model.statusReads.isEmpty, "nothing left to pace the next read against")

    try await waitUntil { !h.model.statusReads.isEmpty }
    #expect(!h.model.statusReads.isEmpty, "and the read it asked for has landed")
    #expect(h.model.workspace.gitStatusIndicator == .stagedOnly)
  }

  /// A prompt's refresh is unpaced no more than the poll is: before this it
  /// ran on every burst of terminal output, three git calls a time.
  @Test func aPromptsRefreshOfASlowWorktreeWaitsForThePaceToo() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let fake = try h.modelOnFakeGit("case \"$*\" in *status*) sleep 0.6;; esac; exit 0")
    fake.statusReads.pace = .standard
    let worktree = try #require(fake.workspace.worktrees.first)

    await fake.refreshStatuses()
    await fake.refreshStatus(of: worktree.id)

    #expect(
      h.gitCalls().filter { $0.contains("status") }.count == 1,
      "a read that took 0.6 s is not due again for 6 s, whoever asks")
  }

  /// Landing last, the read in flight would put the old setting's counts
  /// back. The fake git sleeps in the diff it uses so that it does land last.
  @Test func aReadStartedBeforeTheIndicatorChangedBadgesNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*) printf '## main\\n M README.md\\n';;
        *--cached*) ;;
        *numstat*) sleep 0.5; printf '3\\t0\\tREADME.md\\n';;
      esac
      exit 0
      """)
    let main = try #require(fake.workspace.worktrees.first)

    let stale = Task { await fake.refreshStatus(of: main.id) }
    await Task.yield()
    fake.setGitStatusIndicator(.stagedOnly)
    await stale.value

    try await waitUntil { fake.statuses[main.id] != nil }
    #expect(
      fake.statuses[main.id]?.insertions == 0,
      "the staged-only read, not the staged-and-unstaged one that was already running")
  }

  /// A removal or a stage starting mid-read threw the answer away and left
  /// the badge stale for ten times what that read cost.
  @Test func aReadDiscardedForARowUnderConstructionPacesNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let fake = try h.modelOnFakeGit("case \"$*\" in *status*) sleep 0.6;; esac; exit 0")
    fake.statusReads.pace = .standard
    let main = try #require(fake.workspace.worktrees.first)

    let discarded = Task { await fake.refreshStatus(of: main.id) }
    await Task.yield()
    fake.workInFlight.claim(main.id)
    await discarded.value
    fake.workInFlight.release(main.id)
    await fake.refreshStatus(of: main.id)

    #expect(
      h.gitCalls().filter { $0.contains("status") }.count == 2,
      "the second read is due, the first having badged nothing")
  }

  @Test func openingAProjectRereadsNoRowThePollIsStillReading() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let gate = h.root.appendingPathComponent("go")
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*)
          if [ ! -f "$SCRATCH/first" ]; then
            touch "$SCRATCH/first"
            while [ ! -f "\(gate.path)" ]; do sleep 0.02; done
          fi
          printf '## main\\n' ;;
      esac
      """)
    func statusReads() -> Int { h.gitCalls().filter { $0.contains("status") }.count }

    let poll = Task { await fake.refreshStatuses() }
    try await waitUntil { statusReads() > 0 }
    await fake.refreshStatuses(of: h.project.id)
    try Data().write(to: gate)
    await poll.value

    #expect(statusReads() == 1)
  }

  @Test func aPromptsRefreshWhileThePollReadsItsRowIsReadOnceThePollLands() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let gate = h.root.appendingPathComponent("go")
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*)
          if [ ! -f "$SCRATCH/first" ]; then
            touch "$SCRATCH/first"
            while [ ! -f "\(gate.path)" ]; do sleep 0.02; done
          fi
          printf '## main\\n' ;;
      esac
      """)
    func statusReads() -> Int { h.gitCalls().filter { $0.contains("status") }.count }
    let main = try #require(fake.workspace.worktrees(of: h.project.id).first)
    fake.statusPolling?.cancel()

    let poll = Task { await fake.refreshStatuses() }
    try await waitUntil { statusReads() > 0 }
    await fake.refreshStatus(of: main.id)
    try Data().write(to: gate)
    await poll.value

    try await waitUntil { statusReads() == 2 }
    #expect(statusReads() == 2, "the refresh asked for mid-read was dropped")
  }

  @Test func aTickNamingOneProjectsRecordsLeavesTheOtherProjectUnread() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let second = h.root.appendingPathComponent("other", isDirectory: true)
    try await TestRepository.initialise(at: second, using: h.git)
    try await TestRepository.commitInitial(in: second, using: h.git)
    await h.model.addProject(at: second)
    let other = try #require(h.model.workspace.projects.first { $0.id != h.project.id })
    let common = try #require(await h.model.commonGitDirectory(of: h.project))
    _ = try await h.git.run(
      ["worktree", "add", "-b", "quiet", h.root.appendingPathComponent("quiet").path], in: second)
    h.watcher.watched = []

    await h.model.refreshWorktreesIfRecordsChanged(
      under: [common.appendingPathComponent("worktrees")])
    #expect(
      h.model.workspace.worktrees(of: other.id).count == 1, "the other's records were not read")
    #expect(h.watcher.watched.isEmpty, "nothing changed, so nothing was re-armed")

    await h.model.refreshWorktreesIfRecordsChanged()
    #expect(h.model.workspace.worktrees(of: other.id).count == 2)
    #expect(!h.watcher.watched.isEmpty)
  }

  @Test func aRemovalDialogClosesWhenGitStopsListingItsWorktree() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "asked", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "asked"))
    await h.model.requestWorktreeRemoval(of: created)?.value
    #expect(h.model.pendingWorktreeRemoval?.id == created.id)

    _ = try await h.git.run(
      ["worktree", "remove", "--force", created.path.path], in: h.project.path)
    await h.model.refresh(h.project)

    #expect(h.model.workspace.worktree(created.id) == nil)
    #expect(
      h.model.pendingWorktreeRemoval == nil, "Confirm would remove a path git no longer lists")
  }

  /// A refresh drops the vanished worktree's tabs and sessions, and without
  /// a reconcile the host keeps the surfaces and the shells run on unreachable.
  @Test func aWorktreeRemovedOutsideTheAppTakesItsShellsWithIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "gone", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "gone"))
    let sessions = Set(h.model.workspace.sessions(in: created.id).map(\.id))
    #expect(h.engine.openSessionIDs == sessions)

    _ = try await h.git.run(
      ["worktree", "remove", "--force", created.path.path], in: h.project.path)
    h.engine.focused.removeAll()
    await h.model.refresh(h.project)

    #expect(h.model.workspace.worktree(created.id) == nil)
    #expect(h.engine.openSessionIDs.isEmpty, "the shells outlived the row they belonged to")
    #expect(Set(h.engine.closed) == sessions)
    #expect(
      h.engine.focused.isEmpty,
      "a poll must not pull the keyboard out of what the user is typing in")
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
    await h.model.workInFlight.setup(of: created.id)?.value

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
    await h.model.workInFlight.setup(of: created.id)?.value

    #expect(
      h.model.worktreeOperations[created.id]?.failure
        == "installing\nnpm said no\n\nExited with status 1.",
      "what the hook printed on either stream, then its status, and no rc noise")
  }

  /// `npm install` in a post-create hook used to hold the sheet, and the whole app, for as
  /// long as it took.
  @Test func aSlowPostCreateHookReturnsAtOnceShowsItsProgressAndHoldsTheFirstTab() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 3"), for: h.project)

    await h.model.createWorktree(branch: "slow", basedOn: nil, createBranch: true, in: h.project)

    let created = try #require(h.worktree(onBranch: "slow"))
    // No clock needed: a create that waited out the hook would leave the operation
    // finished and the first tab open, which the next three read.
    #expect(h.model.workspace.selectedWorktreeID == created.id)
    #expect(h.model.worktreeOperations[created.id]?.step == .postCreateHook)
    #expect(h.model.isBusy(created.id))
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "no shell until the hook is done")
    #expect(h.model.liveTerminalCount == 0)

    h.model.newTab()
    h.model.newShellTab()
    h.model.select(created)
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "nothing starts a shell meanwhile")
    h.model.requestWorktreeRemoval(of: created)
    #expect(h.model.pendingWorktreeRemoval == nil, "and nothing removes it meanwhile")

    await h.model.workInFlight.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil)
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(h.model.workspace.tabs(in: created.id).count == 1, "the held-back first tab")
    #expect(h.model.liveTerminalCount == 1)
  }

  /// The two ends of the matrix a create and a selection are asked about
  /// separately: nothing, a shell, or an agent, for each.
  @Test func whatACreatedWorktreeOpensIsAskedApartFromWhatASelectedOneDoes() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setOpensTerminalOnCreate(false)

    await h.model.createWorktree(branch: "quiet", basedOn: nil, createBranch: true, in: h.project)
    let quiet = try #require(h.worktree(onBranch: "quiet"))
    #expect(h.model.workspace.tabs(in: quiet.id).isEmpty, "created, and shown empty")

    let main = try #require(h.worktree(onBranch: "main"))
    h.model.select(main)
    h.model.select(quiet)
    #expect(h.model.workspace.tabs(in: quiet.id).count == 1, "turning to it is the other setting")

    h.model.updateSettings(ProjectSettings(opensTerminalOnCreate: true), for: h.project)
    await h.model.createWorktree(branch: "loud", basedOn: nil, createBranch: true, in: h.project)
    let loud = try #require(h.worktree(onBranch: "loud"))
    #expect(h.model.workspace.tabs(in: loud.id).count == 1, "the project override turns it on")
  }

  @Test func aCreatedWorktreeStartsTheAgentOnItsOwnSettingNotTheTabOpenOne() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setPreferredAgent("claude")
    h.model.setAutoStartAgentOnCreate(true)

    await h.model.createWorktree(branch: "working", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "working"))
    let first = try #require(h.model.workspace.activeTab(in: created.id))
    #expect(
      h.model.workspace.session(first.focusedSessionID)?.agentID == "claude",
      "created, and an agent is already working in it")

    h.model.newTab()
    let second = try #require(h.model.workspace.activeTab(in: created.id))
    #expect(
      h.model.workspace.session(second.focusedSessionID)?.agentID == nil,
      "auto-start on tab open is still off")

    h.model.updateSettings(ProjectSettings(autoStartAgentOnCreate: false), for: h.project)
    await h.model.createWorktree(branch: "plain", basedOn: nil, createBranch: true, in: h.project)
    let plain = try #require(h.worktree(onBranch: "plain"))
    let shell = try #require(h.model.workspace.activeTab(in: plain.id))
    #expect(
      h.model.workspace.session(shell.focusedSessionID)?.agentID == nil,
      "the project override turns it off")
  }

  /// The file is only worth carrying these if the runtime path reads the layered settings
  /// rather than the project's own.
  @Test func aCreatedWorktreeIsAShellWhenOnlyTabOpenAutoStartsTheAgent() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setPreferredAgent("claude")
    h.model.setAutoStartAgent(true)

    await h.model.createWorktree(branch: "byhand", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "byhand"))
    let tab = try #require(h.model.workspace.activeTab(in: created.id))
    #expect(
      h.model.workspace.session(tab.focusedSessionID)?.agentID == nil,
      "auto-start on worktree creation is off, so a shell")

    h.model.newTab()
    let second = try #require(h.model.workspace.activeTab(in: created.id))
    #expect(
      h.model.workspace.session(second.focusedSessionID)?.agentID == "claude",
      "while a tab asked for here is still an agent")
  }

  @Test func aRepositorySaysWhatItsWorktreesOpenAndTheUsersOwnAnswerStillWins() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setPreferredAgent("claude")
    try #"{ "autoStartAgentOnCreate": true, "opensTerminalOnSelect": false }"#
      .write(to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)

    let main = try #require(h.worktree(onBranch: "main"))
    h.model.select(main)
    #expect(h.model.workspace.tabs(in: main.id).isEmpty, "the file says looking does not start one")

    await h.model.createWorktree(branch: "shipped", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "shipped"))
    let tab = try #require(h.model.workspace.activeTab(in: created.id))
    #expect(
      h.model.workspace.session(tab.focusedSessionID)?.agentID == "claude",
      "and that a worktree it made comes up with the agent working")

    h.model.updateSettings(ProjectSettings(opensTerminalOnSelect: true), for: h.project)
    let second = try #require(h.worktree(onBranch: "main"))
    h.model.select(second)
    #expect(
      h.model.workspace.tabs(in: second.id).count == 1, "the user's own answer stands over the file"
    )
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
    let shells = h.root.appendingPathComponent("shells", isDirectory: true)
    try FileManager.default.createDirectory(at: shells, withIntermediateDirectories: true)
    let (zsh, bash) = (shells.appendingPathComponent("zsh"), shells.appendingPathComponent("bash"))
    try Scratch.script("printf zsh > shell.txt", at: zsh)
    try Scratch.script("printf bash > shell.txt", at: bash)
    h.model.setDefaultShell(zsh.path)
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "true", defaultShell: bash.path), for: h.project)

    await h.model.createWorktree(branch: "bashed", basedOn: nil, createBranch: true, in: h.project)

    let created = try #require(h.worktree(onBranch: "bashed"))
    await h.model.workInFlight.setup(of: created.id)?.value
    let shell = try String(
      contentsOf: created.path.appendingPathComponent("shell.txt"), encoding: .utf8)
    #expect(shell == "bash", "the project's shell, not the global one")
  }

  @Test func aHookThatLeavesABackgroundProcessDoesNotHangTheCreate() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "sleep 30 & echo $! > sleep.pid"), for: h.project)

    await h.model.createWorktree(branch: "served", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "served"))
    await h.model.workInFlight.setup(of: created.id)?.value
    let written = try String(
      contentsOf: created.path.appendingPathComponent("sleep.pid"), encoding: .utf8)
    let hookChild = try #require(pid_t(written.trimmingCharacters(in: .whitespacesAndNewlines)))
    defer { kill(hookChild, SIGKILL) }

    #expect(h.model.presentedError == nil)
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(kill(hookChild, 0) == 0, "waited on the hook's child until it exited")
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
      pending.message(warning: h.model.worktreeRemovalWarning(for: worktree))
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

  @Test func withTheTrashOffARemovedWorktreeIsDeletedOutright() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setTrashesRemovedWorktrees(false)
    await h.model.createWorktree(branch: "gone", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "gone"))
    try "uncommitted\n".write(
      to: worktree.path.appendingPathComponent("work.txt"), atomically: true, encoding: .utf8)
    await h.model.refreshStatuses()
    #expect(
      h.model.worktreeRemovalWarning(for: worktree)?.contains("deleted with the directory") == true)

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.platform.trashed.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
    #expect(h.worktree(onBranch: "gone") == nil)
  }

  @Test func aConfirmedRemovalKeepsTheTrashTheDialogNamedThoughTheSettingChanged() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "kept", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "kept"))
    await h.model.requestWorktreeRemoval(of: worktree)?.value
    let pending = try #require(h.model.pendingWorktreeRemoval)
    #expect(pending.message(warning: nil).hasPrefix("Moves "))

    h.model.setTrashesRemovedWorktrees(false)
    await h.model.confirmWorktreeRemoval(pending, deletingBranch: false)

    #expect(h.platform.trashed == [worktree.path])
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
    #expect(refused.retry?.label == "Force Deletion")
    #expect(h.worktree(onBranch: "ahead") == nil, "the worktree itself went")
    #expect(h.model.liveTerminalCount == 0)

    await refused.retry?.action()

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
    #expect(h.model.worktreeCreationStep == nil, "cleared once the sheet's part is over")
    let created = try #require(h.worktree(onBranch: "stepped"))
    await h.model.workInFlight.setup(of: created.id)?.value
  }
}
