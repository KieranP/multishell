import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelWorktreeCreationTests {
  private func firstSession(
    of branch: String,
    _ harness: GitHarness,
  ) throws -> (session: TerminalSession, command: String?) {
    let created = try #require(harness.worktree(onBranch: branch))
    let tab = try #require(harness.model.workspace.activeTab(in: created.id))
    let session = try #require(harness.model.workspace.session(tab.focusedSessionID))
    return (session, harness.engine.opened.last { $0.id == session.id }?.command?.last)
  }

  @Test func theSheetsAgentStartsWithItsTaskWhateverTheCreateSettingsSay() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPreferredAgent("claude")
    harness.model.setOpensTerminalOnCreate(false)

    await harness.model.createWorktree(
      branch: "redirect",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
      firstTab: .agent("codex", task: "Fix the redirect"),
    )

    let first = try firstSession(of: "redirect", harness)
    #expect(first.session.agentID == "codex", "the sheet's pick, not the project's agent")
    #expect(first.command?.hasPrefix("codex -- 'Fix the redirect'; ") == true)
    #expect(harness.model.newWorktreeFirstTabs.isEmpty && harness.model.pendingAgentTasks.isEmpty)
  }

  @Test func theSheetsShellStandsWhereAutoStartOnCreationIsOn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPreferredAgent("claude")
    harness.model.setAutoStartsAgentOnCreate(true)

    await harness.model.createWorktree(
      branch: "plain",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
      firstTab: .shell,
    )
    #expect(try firstSession(of: "plain", harness).session.agentID == nil)

    harness.model.setOpensTerminalOnCreate(false)
    await harness.model.createWorktree(
      branch: "quiet",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
      firstTab: .shell,
    )
    let quiet = try #require(harness.worktree(onBranch: "quiet"))
    #expect(
      harness.model.workspace.tabs(in: quiet.id).isEmpty,
      "a shell still waits on its setting",
    )
    #expect(harness.model.newWorktreeFirstTabs.isEmpty)
  }

  @Test func theSheetsAgentWaitsForThePostCreateHookAndThenStarts() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(postCreateHook: "true"), for: harness.project)

    await harness.model.createWorktree(
      branch: "hooked",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
      firstTab: .agent("claude", task: "Fix the redirect"),
    )
    let created = try #require(harness.worktree(onBranch: "hooked"))
    #expect(harness.model.workspace.tabs(in: created.id).isEmpty, "held back while the hook runs")
    await harness.model.stageHandles.setupTask(of: created.id)?.value

    let first = try firstSession(of: "hooked", harness)
    #expect(first.session.agentID == "claude")
    #expect(first.command?.hasPrefix("claude -- 'Fix the redirect'; ") == true)
    #expect(harness.model.newWorktreeFirstTabs.isEmpty)
  }

  @Test func aFailedHooksDismissStartsTheSheetsAgent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(postCreateHook: "exit 3"), for: harness.project)

    await harness.model.createWorktree(
      branch: "hooked",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
      firstTab: .agent("claude", task: "Fix the redirect"),
    )
    let created = try #require(harness.worktree(onBranch: "hooked"))
    await harness.model.stageHandles.setupTask(of: created.id)?.value
    harness.model.dismissOperationFailure(of: created)

    let first = try firstSession(of: "hooked", harness)
    #expect(first.session.agentID == "claude")
    #expect(first.command?.hasPrefix("claude -- 'Fix the redirect'; ") == true)
  }

  @Test func aWorktreeRemadeWhereAFailedOneWasRemovedDoesNotInheritItsSheetsAgent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(postCreateHook: "exit 3"), for: harness.project)
    await harness.model.createWorktree(
      branch: "hooked",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
      firstTab: .agent("claude", task: "Fix the redirect"),
    )
    let failed = try #require(harness.worktree(onBranch: "hooked"))
    await harness.model.stageHandles.setupTask(of: failed.id)?.value
    try await harness.removeOutsideTheApp(failed.path)
    await harness.model.refreshWorktrees(of: harness.project)

    harness.model.setSettings(ProjectSettings(), for: harness.project)
    await harness.model.createWorktree(
      branch: "hooked",
      basedOn: nil,
      createsBranch: false,
      in: harness.project,
    )
    let remade = try #require(harness.worktree(onBranch: "hooked"))
    #expect(remade.id == failed.id)
    await harness.model.stageHandles.setupTask(of: remade.id)?.value

    #expect(try firstSession(of: "hooked", harness).session.agentID == nil)
  }
}
