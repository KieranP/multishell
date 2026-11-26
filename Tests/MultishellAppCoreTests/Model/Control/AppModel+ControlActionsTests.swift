import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlActionsTests {
  private let serve = ProjectAction(name: "Start Server", command: "npm run dev")

  private func harnessWithServe() -> (Harness, String) {
    let harness = Harness()
    harness.model.setSettings(ProjectSettings(actions: [serve]), for: harness.project)
    return (harness, ControlID.worktree(harness.main.id))
  }

  @Test func theListNamesEachActionWithItsState() async throws {
    let (harness, id) = harnessWithServe()

    let reply = await harness.model.answer(.listActions(worktree: id))

    let actions = try #require(reply.outputFields["actions"] as? [[String: Any]])
    #expect(actions.first?["name"] as? String == serve.name)
    #expect(actions.first?["state"] as? String == "idle")
  }

  @Test func runningAnActionOpensItsTabAsThePlayMenuDoes() async throws {
    let (harness, id) = harnessWithServe()

    let reply = await harness.model.answer(
      .runAction(worktree: id, name: serve.name, restart: false, force: false)
    )

    #expect(reply == .done)
    #expect(harness.model.actionSession(named: serve.name, in: harness.main.id) != nil)
  }

  @Test func oneStillRunningIsRefusedWithoutRestartAndRestartedWithIt() async throws {
    let (harness, id) = harnessWithServe()
    _ = await harness.model.answer(
      .runAction(worktree: id, name: serve.name, restart: false, force: false)
    )
    let first = try #require(harness.model.actionSession(named: serve.name, in: harness.main.id))
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: first.id, isFromShellIntegration: true)
    )

    let refused = await harness.model.answer(
      .runAction(worktree: id, name: serve.name, restart: false, force: false)
    )
    #expect(refused == .refused(.actionTabOccupied(name: serve.name)))
    #expect(harness.model.pendingActionRestart == nil, "a script cannot answer a dialog")

    let restarted = await harness.model.answer(
      .runAction(worktree: id, name: serve.name, restart: true, force: false)
    )
    #expect(restarted == .done)
    #expect(harness.model.actionSession(named: serve.name, in: harness.main.id)?.id != first.id)
    #expect(harness.engine.closed.contains(first.id))
  }

  @Test func anUnknownActionAndAnUntrustedFilesAreRefusedApart() async throws {
    let (harness, id) = harnessWithServe()
    try #"{ "actions": [ { "name": "Seed", "command": "bin/rails db:seed" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()

    #expect(
      await harness.model.answer(
        .runAction(worktree: id, name: "Seed", restart: false, force: false)
      )
        == .refused(.actionNotTrusted(name: "Seed"))
    )
    #expect(
      await harness.model.answer(
        .runAction(worktree: id, name: "Deploy", restart: false, force: false)
      )
        == .refused(.actionNotFound(name: "Deploy"))
    )
  }

  @Test func aWorktreeBeingRemovedIsRefusedAsNotReady() async {
    let (harness, id) = harnessWithServe()
    harness.model.worktreeOperations.begin(.preDeleteHook, on: harness.main.id)

    let reply = await harness.model.answer(
      .runAction(worktree: id, name: serve.name, restart: false, force: false)
    )

    #expect(reply == .refused(.worktreeNotReady(id: id)))
    #expect(harness.model.workspace.tabs.isEmpty)
  }

  @Test func actionsAndTheirKeysAreNotSetThroughConfigProject() async {
    let (harness, _) = harnessWithServe()
    let project = ControlID.project(harness.project.id)

    let keys = await harness.model.answer(
      .writeProjectSetting(
        project: project,
        key: "actionShortcuts",
        value: #"{"Start Server":"cmd+t"}"#,
      )
    )
    let actions = await harness.model.answer(
      .writeProjectSetting(project: project, key: "actions", value: "[]")
    )

    #expect(keys == .refused(.noSetting(key: "actionShortcuts")))
    #expect(actions == .refused(.noSetting(key: "actions")))
  }

  @Test func anotherSettingSetThroughConfigProjectKeepsAnUnfilledActionRow() async {
    let harness = Harness()
    harness.model.addAction(to: harness.project)

    let reply = await harness.model.answer(
      .writeProjectSetting(
        project: ControlID.project(harness.project.id),
        key: "branchPrefix",
        value: "feat/",
      )
    )

    #expect(reply == .done)
    #expect(harness.model.ownSettings(of: harness.project).actions.count == 1)
  }

  @Test func aRestartOverAWorkingAgentIsRefusedWithoutForce() async throws {
    let (harness, id) = harnessWithServe()
    _ = await harness.model.answer(
      .runAction(worktree: id, name: serve.name, restart: false, force: false)
    )
    let session = try #require(harness.model.actionSession(named: serve.name, in: harness.main.id))
    harness.model.noteCommandFinished(in: session.id, exitCode: 1)
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "claude")
    )

    let refused = await harness.model.answer(
      .runAction(worktree: id, name: serve.name, restart: true, force: false)
    )
    #expect(refused == .refused(.agentWorking))
    #expect(!harness.engine.closed.contains(session.id))

    let forced = await harness.model.answer(
      .runAction(worktree: id, name: serve.name, restart: true, force: true)
    )
    #expect(forced == .done)
    #expect(harness.engine.closed.contains(session.id))
  }

  @Test func runningAnActionInAnotherWorktreeLeavesTheViewWhereItWas() async throws {
    let (harness, _) = harnessWithServe()
    harness.model.select(harness.main)
    let feature = ControlID.worktree(harness.feature.id)

    let reply = await harness.model.answer(
      .runAction(worktree: feature, name: serve.name, restart: false, force: false)
    )

    #expect(reply == .done)
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    let session = try #require(
      harness.model.actionSession(named: serve.name, in: harness.feature.id)
    )
    #expect(harness.engine.opened.contains { $0.id == session.id })
  }

  @Test func restartingAnActionInAnotherWorktreeLeavesTheViewWhereItWas() async throws {
    let (harness, _) = harnessWithServe()
    let feature = ControlID.worktree(harness.feature.id)
    _ = await harness.model.answer(
      .runAction(worktree: feature, name: serve.name, restart: false, force: false)
    )
    let first = try #require(
      harness.model.actionSession(named: serve.name, in: harness.feature.id)
    )
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: first.id, isFromShellIntegration: true)
    )
    harness.model.select(harness.main)

    let reply = await harness.model.answer(
      .runAction(worktree: feature, name: serve.name, restart: true, force: false)
    )

    #expect(reply == .done)
    #expect(harness.engine.closed.contains(first.id))
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
  }

  @Test func anAgentWaitingAtItsPromptInTheActionsTabIsRefusedWithoutRestart() async throws {
    let (harness, id) = harnessWithServe()
    harness.model.runAction(named: serve.name, in: harness.main)
    let session = try #require(harness.model.actionSession(named: serve.name, in: harness.main.id))
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: session.id, isFromShellIntegration: true)
    )
    harness.model.noteCommandFinished(in: session.id, exitCode: 0)
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "claude")
    )
    harness.messageSource.send(
      SessionStateReport(state: .done, sessionID: session.id, agentID: "claude")
    )

    let reply = await harness.model.answer(
      .runAction(worktree: id, name: serve.name, restart: false, force: false)
    )

    #expect(reply == .refused(.actionTabOccupied(name: serve.name)))
    #expect(!harness.engine.closed.contains(session.id))
  }
}
