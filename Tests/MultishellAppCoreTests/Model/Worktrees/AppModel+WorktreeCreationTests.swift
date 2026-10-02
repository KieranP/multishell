import Foundation
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelWorktreeCreationTests {
  @Test func creatingAWorktreeSelectsItOpensAShellAndWatchesItsRecords() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    await harness.model.createWorktree(
      branch: "feat/tabs", basedOn: nil, createsBranch: true, in: harness.project)

    let created = try #require(harness.worktree(onBranch: "feat/tabs"))
    #expect(harness.model.presentedError == nil)
    #expect(created.path.lastPathComponent == "feat-tabs")
    #expect(FileManager.default.fileExists(atPath: created.path.path))
    #expect(harness.model.workspace.selectedWorktreeID == created.id)
    #expect(harness.model.workspace.tabs(in: created.id).count == 1)
    #expect(harness.model.liveTerminalCount == 1)
    #expect(
      harness.engine.liveSessionIDs
        == Set(harness.model.workspace.sessions(in: created.id).map(\.id)))
    #expect(
      harness.watcher.watched.map(\.lastPathComponent).sorted() == ["feat-tabs", "worktrees"],
      "the linked worktree's own record directory is watched for branch switches")
  }

  /// A create and a selection each have their own setting for opening a
  /// terminal, and a project's override reaches the create's.
  @Test func aCreatedWorktreeOpensATerminalByItsOwnSettingNotTheSelections() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setOpensTerminalOnCreate(false)

    await harness.model.createWorktree(
      branch: "quiet", basedOn: nil, createsBranch: true, in: harness.project)
    let quiet = try #require(harness.worktree(onBranch: "quiet"))
    #expect(harness.model.workspace.tabs(in: quiet.id).isEmpty, "created, and shown empty")

    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.select(quiet)
    #expect(
      harness.model.workspace.tabs(in: quiet.id).count == 1, "turning to it is the other setting")

    harness.model.setSettings(ProjectSettings(opensTerminalOnCreate: true), for: harness.project)
    await harness.model.createWorktree(
      branch: "loud", basedOn: nil, createsBranch: true, in: harness.project)
    let loud = try #require(harness.worktree(onBranch: "loud"))
    #expect(
      harness.model.workspace.tabs(in: loud.id).count == 1, "the project override turns it on")
  }

  @Test func aCreatedWorktreeStartsTheAgentOnItsOwnSettingNotTheTabOpenOne() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPreferredAgent("claude")
    harness.model.setAutoStartsAgentOnCreate(true)

    await harness.model.createWorktree(
      branch: "working", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "working"))
    let first = try #require(harness.model.workspace.activeTab(in: created.id))
    #expect(
      harness.model.workspace.session(first.focusedSessionID)?.agentID == "claude",
      "created, and an agent is already working in it")

    harness.model.newTab()
    let second = try #require(harness.model.workspace.activeTab(in: created.id))
    #expect(
      harness.model.workspace.session(second.focusedSessionID)?.agentID == nil,
      "auto-start on tab open is still off")

    harness.model.setSettings(ProjectSettings(autoStartsAgentOnCreate: false), for: harness.project)
    await harness.model.createWorktree(
      branch: "plain", basedOn: nil, createsBranch: true, in: harness.project)
    let plain = try #require(harness.worktree(onBranch: "plain"))
    let shell = try #require(harness.model.workspace.activeTab(in: plain.id))
    #expect(
      harness.model.workspace.session(shell.focusedSessionID)?.agentID == nil,
      "the project override turns it off")
  }

  @Test func aCreatedWorktreeIsAShellWhenOnlyTabOpenAutoStartsTheAgent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPreferredAgent("claude")
    harness.model.setAutoStartsAgent(true)

    await harness.model.createWorktree(
      branch: "byhand", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "byhand"))
    let tab = try #require(harness.model.workspace.activeTab(in: created.id))
    #expect(
      harness.model.workspace.session(tab.focusedSessionID)?.agentID == nil,
      "auto-start on worktree creation is off, so a shell")

    harness.model.newTab()
    let second = try #require(harness.model.workspace.activeTab(in: created.id))
    #expect(
      harness.model.workspace.session(second.focusedSessionID)?.agentID == "claude",
      "while a tab asked for here is still an agent")
  }

  @Test func aRepositorySaysWhatItsWorktreesOpenAndTheUsersOwnAnswerStillWins() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPreferredAgent("claude")
    try harness.writeSharedSettings(
      #"{ "autoStartAgentOnCreate": true, "opensTerminalOnSelect": false }"#)
    await harness.model.refreshWorktrees(of: harness.project)

    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    #expect(
      harness.model.workspace.tabs(in: main.id).isEmpty, "the file says looking does not start one")

    await harness.model.createWorktree(
      branch: "shipped", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "shipped"))
    let tab = try #require(harness.model.workspace.activeTab(in: created.id))
    #expect(
      harness.model.workspace.session(tab.focusedSessionID)?.agentID == "claude",
      "and that a worktree it made comes up with the agent working")

    harness.model.setSettings(ProjectSettings(opensTerminalOnSelect: true), for: harness.project)
    let second = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(second)
    #expect(
      harness.model.workspace.tabs(in: second.id).count == 1,
      "the user's own answer stands over the file"
    )
  }

  @Test func aFailingPreCreateHookCreatesNothingAndSelectsNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(
      ProjectSettings(preCreateHook: "echo no >&2\nexit 3"), for: harness.project)

    await harness.model.createWorktree(
      branch: "refused", basedOn: nil, createsBranch: true, in: harness.project)

    #expect(harness.worktree(onBranch: "refused") == nil)
    #expect(
      harness.model.presentedError?.title == "Worktree not created: its pre-create hook failed")
    #expect(
      harness.model.presentedError?.message == "no\n\nExited with status 3.",
      "the hook's line and its status, and no rc noise")
    #expect(harness.model.workspace.selectedWorktreeID == nil)
    #expect(harness.model.liveTerminalCount == 0)
  }

  @Test func theSheetSeesThePreCreateHookThenNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(
      ProjectSettings(preCreateHook: "sleep 1", postCreateHook: "true"), for: harness.project)

    let create = Task {
      await harness.model.createWorktree(
        branch: "stepped", basedOn: nil, createsBranch: true, in: harness.project)
    }
    var seen: Set<WorktreeCreationStep> = []
    try await waitUntil(
      {
        guard let step = harness.model.worktreeCreationStep else { return !seen.isEmpty }
        seen.insert(step)
        return false
      }, seconds: 15)
    await create.value

    #expect(seen.contains(.preCreateHook), "the sheet could name the hook it waited on: \(seen)")
    #expect(harness.model.worktreeCreationStep == nil, "cleared once the sheet's part is over")
    let created = try #require(harness.worktree(onBranch: "stepped"))
    await harness.model.stageHandles.setup(of: created.id)?.value
  }

  /// A checkout held by an LFS smudge or a credential helper on a dead
  /// network: the sheet's Cancel has to end git as it ends the hook before it.
  @Test func cancelWhileGitAddsTheWorktreeEndsItAndReportsNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let slow = try harness.modelOnFakeGit(
      """
      case "$1 $2" in
        "worktree add") sleep 30 ;;
      esac
      """)
    let began = ContinuousClock.now

    let create = Task {
      await slow.createWorktree(
        branch: "held", basedOn: nil, createsBranch: true, in: harness.project)
    }
    try await waitUntil { slow.worktreeCreationStep == .addingWorktree }
    #expect(slow.worktreeCreationStep == .addingWorktree)
    slow.cancelWorktreeCreation()
    await create.value

    #expect(ContinuousClock.now - began < .seconds(12), "signalled, not waited out")
    #expect(slow.presentedError == nil, "the user's own Cancel is nothing to report")
    #expect(slow.worktreeCreationStep == nil)
  }

  /// Steps reach the main actor through a hop, and the create clears the
  /// slot as it returns, so a later one must not fill it again.
  @Test func aStepReportedAfterItsCreateEndedIsDropped() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "done", basedOn: nil, createsBranch: true, in: harness.project)
    #expect(harness.model.worktreeCreationStep == nil)

    harness.model.noteCreationStep(.addingWorktree, of: ProcessStopper())

    #expect(harness.model.worktreeCreationStep == nil, "no create owns that stopper any more")
  }

  /// The settings window is its own scene, so a sheet outlives a removal
  /// confirmed there. Its Create used to add a worktree nothing lists.
  @Test func creatingFromASheetHeldOpenAcrossARemovalTouchesNothingOnDisk() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let project = harness.project
    let container = harness.model.effectiveWorktreeSettings(for: project).worktreeContainer(
      for: project)

    harness.model.requestNewWorktree(in: project)
    harness.model.removeProject(project)
    #expect(harness.model.newWorktreeRequest == nil, "the sheet goes with the project")

    await harness.model.createWorktree(
      branch: "orphan", basedOn: nil, createsBranch: true, in: project)

    #expect(harness.model.workspace.projects.isEmpty)
    #expect(harness.model.presentedError == nil)
    #expect(
      !FileManager.default.fileExists(atPath: container.appendingPathComponent("orphan").path),
      "no worktree directory for a project that has left")
  }

  @Test func cancellingTheSheetDuringThePreCreateHookCreatesNothingAndSaysNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(preCreateHook: "sleep 30"), for: harness.project)
    let create = Task {
      await harness.model.createWorktree(
        branch: "never", basedOn: nil, createsBranch: true, in: harness.project)
    }
    try await waitUntil { harness.model.worktreeCreationStep == .preCreateHook }
    #expect(harness.model.worktreeCreationStep == .preCreateHook)

    harness.model.cancelWorktreeCreation()
    await create.value

    #expect(harness.model.presentedError == nil)
    #expect(harness.worktree(onBranch: "never") == nil)
    #expect(harness.model.worktreeCreationStep == nil)
  }

  /// git rejects the name at the end of a create, by which time the hook
  /// has run and the container directory is there.
  @Test func aBranchNameGitWillRefuseRunsNoHookAndMakesNoDirectory() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let marker = harness.root.appendingPathComponent("hook-ran")
    let container = harness.model.effectiveWorktreeSettings(for: harness.project).worktreeContainer(
      for: harness.project)
    harness.model.setSettings(
      ProjectSettings(preCreateHook: "touch \(marker.path)"), for: harness.project)

    await harness.model.createWorktree(
      branch: "my branch", basedOn: nil, createsBranch: true, in: harness.project)

    #expect(!FileManager.default.fileExists(atPath: marker.path), "the hook did not run")
    #expect(!FileManager.default.fileExists(atPath: container.path), "nor the directory made")
    #expect(harness.model.presentedError != nil, "and the sheet says why")
    #expect(harness.worktree(onBranch: "my branch") == nil)
  }

  /// Nothing in the model stops two creates overlapping, so each holds its
  /// own row: one slot would leave whichever started first badged mid-add.
  @Test func twoCreatesAtOnceEachHoldTheirOwnRow() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("go")
    harness.model.setSettings(
      ProjectSettings(preCreateHook: "while [ ! -f \"\(gate.path)\" ]; do sleep 0.02; done"),
      for: harness.project)

    func planned(_ branch: String) throws -> Worktree.ID {
      try #require(
        harness.model.plannedPath(forBranch: branch, createsBranch: true, in: harness.project)
      )
      .standardizedFileURL.path
    }
    let plannedOne = try planned("one")
    let plannedTwo = try planned("two")
    let first = Task {
      await harness.model.createWorktree(
        branch: "one", basedOn: nil, createsBranch: true, in: harness.project)
    }
    let second = Task {
      await harness.model.createWorktree(
        branch: "two", basedOn: nil, createsBranch: true, in: harness.project)
    }
    let claims = { harness.model.pathClaims }
    try await waitUntil(
      { claims().isClaimed(plannedOne) && claims().isClaimed(plannedTwo) }, seconds: 5)
    #expect(claims().isClaimed(plannedOne) && claims().isClaimed(plannedTwo), "both, not the later")

    try Data().write(to: gate)
    await first.value
    await second.value

    #expect(!claims().isClaimed(plannedOne) && !claims().isClaimed(plannedTwo), "each let go")
    let one = try #require(harness.worktree(onBranch: "one"))
    let two = try #require(harness.worktree(onBranch: "two"))
    #expect([one.id, two.id] == [plannedOne, plannedTwo], "what was held is what git listed")
  }

  /// Two creates naming one path, one of them doomed: the first to end
  /// must not let go of a path the other is still checking out into.
  @Test func twoCreatesOnOnePathHoldItUntilTheLastLetsGo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let planned = harness.root.appendingPathComponent("twice", isDirectory: true)
    let id = try #require(harness.model.claimPath(planned))
    #expect(harness.model.claimPath(planned) == id)

    harness.model.releasePathClaim(id, in: harness.project)
    #expect(harness.model.isBeingWritten(id), "one still holds it")

    harness.model.releasePathClaim(id, in: harness.project)
    #expect(!harness.model.isBeingWritten(id))
  }
}
