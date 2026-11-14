import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelControlWorktreesTests {
  private func selectMainCheckout(of harness: GitHarness) throws -> Worktree {
    let main = try #require(
      harness.model.workspace.worktrees(of: harness.project.id).first { $0.isPrimary }
    )
    try #require(harness.model.select(main))
    return main
  }

  private func firstCommand(
    in worktree: Worktree,
    _ harness: GitHarness,
  ) throws -> (agentID: String?, command: String?) {
    let tab = try #require(harness.model.workspace.activeTab(in: worktree.id))
    let session = try #require(harness.model.workspace.session(tab.focusedSessionID))
    let opened = harness.engine.opened.last { $0.id == session.id }
    return (session.agentID, opened?.command?.last?.withoutLeadingPathStatement)
  }

  @Test func aWorktreeMadeInTheBackgroundLeavesTheViewAndStartsItsAgentOutOfIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try selectMainCheckout(of: harness)
    let focusedBefore = harness.engine.focused.count

    let reply = await harness.model.answer(
      .newWorktree(
        order("feat/bg", in: harness, agentID: "claude", task: "fix it", selectsWorktree: false)
      )
    )

    let created = try #require(harness.worktree(onBranch: "feat/bg"), "\(reply)")
    #expect(harness.model.workspace.selectedWorktreeID == main.id)
    #expect(harness.engine.focused.count == focusedBefore)
    let first = try firstCommand(in: created, harness)
    #expect(first.agentID == "claude")
    #expect(first.command?.hasPrefix("claude -- 'fix it'\n") == true, "\(first.command ?? "")")
    #expect(harness.model.newWorktreeFirstTabs.isEmpty)
  }

  @Test func aWorktreeMadeInTheBackgroundStartsItsAgentOnceThePostCreateHookEnds() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(postCreateHook: "true"), for: harness.project)
    let main = try selectMainCheckout(of: harness)

    _ = await harness.model.answer(
      .newWorktree(
        order(
          "feat/hooked",
          in: harness,
          agentID: "claude",
          task: "fix it",
          selectsWorktree: false,
        )
      )
    )
    let created = try #require(harness.worktree(onBranch: "feat/hooked"))
    #expect(harness.model.workspace.tabs(in: created.id).isEmpty)
    await harness.model.stageHandles.setupTask(of: created.id)?.value

    #expect(harness.model.workspace.selectedWorktreeID == main.id)
    let first = try firstCommand(in: created, harness)
    #expect(first.agentID == "claude")
    #expect(first.command?.hasPrefix("claude -- 'fix it'\n") == true, "\(first.command ?? "")")
  }

  @Test func twoWorktreesMadeInTheBackgroundAtOnceAreBothMadeAndLeaveTheView() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try selectMainCheckout(of: harness)

    async let first = harness.model.answer(
      .newWorktree(order("feat/one", in: harness, selectsWorktree: false))
    )
    async let second = harness.model.answer(
      .newWorktree(order("feat/two", in: harness, selectsWorktree: false))
    )
    let replies = await [first, second]

    #expect(replies.allSatisfy { $0.refusal == nil }, "\(replies)")
    #expect(harness.worktree(onBranch: "feat/one") != nil)
    #expect(harness.worktree(onBranch: "feat/two") != nil)
    #expect(harness.model.workspace.selectedWorktreeID == main.id)
  }
}
