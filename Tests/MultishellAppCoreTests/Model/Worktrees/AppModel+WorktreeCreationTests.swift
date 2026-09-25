import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelWorktreeCreationTests {
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
    let read = try #require(await h.model.newWorktreeBranches(of: project))
    let checkedOut = Set(h.model.workspace.worktrees(of: project.id).compactMap(\.branch))
    draft.finishLoading(project.id, with: read, checkedOut: checkedOut)

    #expect(draft.availableBranches(checkedOut: checkedOut) == ["release", "spike"])
    draft.createBranch = false
    draft.modeChanged(checkedOut: checkedOut)
    #expect(draft.branch == "release")
    #expect(draft.canCreate(checkedOut: checkedOut))
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
    await h.model.stageHandles.setup(of: created.id)?.value
  }

  /// A checkout held by an LFS smudge or a credential helper on a dead
  /// network: the sheet's Cancel has to end git as it ends the hook before it.
  @Test func cancelWhileGitAddsTheWorktreeEndsItAndReportsNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let slow = try h.modelOnFakeGit(
      """
      case "$1 $2" in
        "worktree add") sleep 30 ;;
      esac
      """)
    let began = ContinuousClock.now

    let create = Task {
      await slow.createWorktree(branch: "held", basedOn: nil, createBranch: true, in: h.project)
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
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "done", basedOn: nil, createBranch: true, in: h.project)
    #expect(h.model.worktreeCreationStep == nil)

    h.model.noteCreationStep(.addingWorktree, of: ProcessStopper())

    #expect(h.model.worktreeCreationStep == nil, "no create owns that stopper any more")
  }

  /// The settings window is its own scene, so a sheet outlives a removal
  /// confirmed there. Its Create used to add a worktree nothing lists.
  @Test func creatingFromASheetHeldOpenAcrossARemovalTouchesNothingOnDisk() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    let container = h.model.worktreeSettings(for: project).worktreeContainer(for: project)

    h.model.requestNewWorktree(in: project)
    h.model.removeProject(project)
    #expect(h.model.newWorktreeRequest == nil, "the sheet goes with the project")

    await h.model.createWorktree(branch: "orphan", basedOn: nil, createBranch: true, in: project)

    #expect(h.model.workspace.projects.isEmpty)
    #expect(h.model.presentedError == nil)
    #expect(
      !FileManager.default.fileExists(atPath: container.appendingPathComponent("orphan").path),
      "no worktree directory for a project that has left")
  }

  @Test func cancellingTheSheetDuringThePreCreateHookCreatesNothingAndSaysNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(preCreateHook: "sleep 30"), for: h.project)
    let create = Task {
      await h.model.createWorktree(branch: "never", basedOn: nil, createBranch: true, in: h.project)
    }
    try await waitUntil { h.model.worktreeCreationStep == .preCreateHook }
    #expect(h.model.worktreeCreationStep == .preCreateHook)

    h.model.cancelWorktreeCreation()
    await create.value

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "never") == nil)
    #expect(h.model.worktreeCreationStep == nil)
  }

  /// git rejects the name at the end of a create, by which time the hook
  /// has run and the container directory is there.
  @Test func aBranchNameGitWillRefuseRunsNoHookAndMakesNoDirectory() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let marker = h.root.appendingPathComponent("hook-ran")
    h.model.updateSettings(
      ProjectSettings(preCreateHook: "touch \(marker.path)"), for: h.project)

    await h.model.createWorktree(
      branch: "my branch", basedOn: nil, createBranch: true, in: h.project)

    #expect(!FileManager.default.fileExists(atPath: marker.path), "the hook did not run")
    #expect(h.model.presentedError != nil, "and the sheet says why")
    #expect(h.worktree(onBranch: "my branch") == nil)
  }

  @Test func thePlannedLocationPlacesTheTrimmedNameAndIsADashWithoutOne() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    var draft = NewWorktreeDraft(projectID: h.project.id)
    #expect(h.model.plannedLocation(for: draft) == "\u{2014}", "no name typed")

    draft.branch = "  feat/x "

    #expect(h.model.plannedLocation(for: draft).hasSuffix("/feat-x"))
    draft.projectID = nil
    #expect(h.model.plannedLocation(for: draft) == "\u{2014}", "no project picked")
  }
}
