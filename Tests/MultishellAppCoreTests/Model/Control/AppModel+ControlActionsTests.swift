import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlActionsTests {
  private func harnessWithServe() -> (Harness, String) {
    let harness = Harness.withServeAction()
    return (harness, ControlID.worktree(harness.main.id))
  }

  @Test func theListNamesEachActionWithItsState() async throws {
    let (harness, id) = harnessWithServe()

    let reply = await harness.model.answer(.listActions(worktree: id))

    let actions = try #require(reply.outputFields["actions"] as? [[String: Any]])
    #expect(actions.first?["name"] as? String == ProjectAction.serve.name)
    #expect(actions.first?["state"] as? String == "idle")
  }

  @Test func runningAnActionOpensItsTabAsThePlayMenuDoes() async throws {
    let (harness, id) = harnessWithServe()

    let reply = await harness.model.answer(
      .runAction(worktree: id, name: ProjectAction.serve.name, restart: false, force: false)
    )

    #expect(reply == .done)
    #expect(
      harness.model.actionSession(named: ProjectAction.serve.name, in: harness.main.id) != nil
    )
  }

  @Test func oneStillRunningIsRefusedWithoutRestartAndRestartedWithIt() async throws {
    let (harness, id) = harnessWithServe()
    _ = await harness.model.answer(
      .runAction(worktree: id, name: ProjectAction.serve.name, restart: false, force: false)
    )
    let first = try #require(
      harness.model.actionSession(named: ProjectAction.serve.name, in: harness.main.id)
    )
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: first.id, isFromShellIntegration: true)
    )

    let refused = await harness.model.answer(
      .runAction(worktree: id, name: ProjectAction.serve.name, restart: false, force: false)
    )
    #expect(refused == .refused(.actionTabOccupied(name: ProjectAction.serve.name)))
    #expect(harness.model.pendingActionRestart == nil, "a script cannot answer a dialog")

    let restarted = await harness.model.answer(
      .runAction(worktree: id, name: ProjectAction.serve.name, restart: true, force: false)
    )
    #expect(restarted == .done)
    #expect(
      harness.model.actionSession(named: ProjectAction.serve.name, in: harness.main.id)?.id
        != first.id
    )
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
      .runAction(worktree: id, name: ProjectAction.serve.name, restart: false, force: false)
    )

    #expect(reply == .refused(.worktreeNotReady(id: id)))
    #expect(harness.model.workspace.tabs.isEmpty)
  }

  @Test func aRestartOverAWorkingAgentIsRefusedWithoutForce() async throws {
    let (harness, id) = harnessWithServe()
    _ = await harness.model.answer(
      .runAction(worktree: id, name: ProjectAction.serve.name, restart: false, force: false)
    )
    let session = try #require(
      harness.model.actionSession(named: ProjectAction.serve.name, in: harness.main.id)
    )
    harness.model.noteCommandFinished(in: session.id, exitCode: 1)
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "claude")
    )

    let refused = await harness.model.answer(
      .runAction(worktree: id, name: ProjectAction.serve.name, restart: true, force: false)
    )
    #expect(refused == .refused(.agentWorking))
    #expect(!harness.engine.closed.contains(session.id))

    let forced = await harness.model.answer(
      .runAction(worktree: id, name: ProjectAction.serve.name, restart: true, force: true)
    )
    #expect(forced == .done)
    #expect(harness.engine.closed.contains(session.id))
  }

  @Test func runningAnActionInAnotherWorktreeLeavesTheViewWhereItWas() async throws {
    let (harness, _) = harnessWithServe()
    harness.model.select(harness.main)
    let feature = ControlID.worktree(harness.feature.id)

    let reply = await harness.model.answer(
      .runAction(worktree: feature, name: ProjectAction.serve.name, restart: false, force: false)
    )

    #expect(reply == .done)
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    let session = try #require(
      harness.model.actionSession(named: ProjectAction.serve.name, in: harness.feature.id)
    )
    #expect(harness.engine.opened.contains { $0.id == session.id })
  }

  @Test func restartingAnActionInAnotherWorktreeLeavesTheViewWhereItWas() async throws {
    let (harness, _) = harnessWithServe()
    let feature = ControlID.worktree(harness.feature.id)
    _ = await harness.model.answer(
      .runAction(worktree: feature, name: ProjectAction.serve.name, restart: false, force: false)
    )
    let first = try #require(
      harness.model.actionSession(named: ProjectAction.serve.name, in: harness.feature.id)
    )
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: first.id, isFromShellIntegration: true)
    )
    harness.model.select(harness.main)

    let reply = await harness.model.answer(
      .runAction(worktree: feature, name: ProjectAction.serve.name, restart: true, force: false)
    )

    #expect(reply == .done)
    #expect(harness.engine.closed.contains(first.id))
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
  }

  @Test func anAgentWaitingAtItsPromptInTheActionsTabIsRefusedWithoutRestart() async throws {
    let (harness, id) = harnessWithServe()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let session = try #require(
      harness.model.actionSession(named: ProjectAction.serve.name, in: harness.main.id)
    )
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
      .runAction(worktree: id, name: ProjectAction.serve.name, restart: false, force: false)
    )

    #expect(reply == .refused(.actionTabOccupied(name: ProjectAction.serve.name)))
    #expect(!harness.engine.closed.contains(session.id))
  }
}
