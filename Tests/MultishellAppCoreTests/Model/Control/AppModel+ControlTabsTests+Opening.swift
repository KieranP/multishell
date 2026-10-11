import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellProcess

extension AppModelControlTabsTests {
  @Test func aTabAskedForInTheWorktreeInViewRunsTheCommandThereAndTakesTheKeyboard() async throws {
    let harness = Harness()
    harness.model.select(harness.main)

    let reply = try #require(
      await harness.stateSource.ask(
        .newTab(order(ControlID.worktree(harness.main.id), command: ["npm", "run", "dev"]))
      )
    )

    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    #expect(reply.outputFields["tab"] as? String == tab.id.uuidString)
    #expect(reply.outputFields["pane"] as? String == tab.focusedSessionID.uuidString)
    #expect(harness.model.title(of: tab) == "npm")
    let opened = try #require(harness.engine.opened.last)
    #expect(opened.id == tab.focusedSessionID)
    #expect(
      opened.command?.last?.withoutLeadingPathStatement.hasPrefix("npm run dev; ") == true,
      "\(opened.command ?? [])",
    )
    #expect(harness.engine.focused.last == tab.focusedSessionID)
  }

  @Test func aTabAskedForInAnotherWorktreeStartsThereAndLeavesTheViewAlone() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let feature = ControlID.worktree(harness.feature.id)

    let reply = try #require(await harness.stateSource.ask(.newTab(order(feature))))

    #expect(reply.refusal == nil)
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.feature.id))
    #expect(harness.engine.liveSessionIDs.contains(tab.focusedSessionID), "it runs out of view")
    #expect(harness.engine.focused.last != tab.focusedSessionID)
  }

  @Test func anIDNoWorktreeHasIsRefusedByThatID() async throws {
    let harness = Harness()

    let reply = await harness.stateSource.ask(.newTab(order("w-00000000")))

    #expect(reply == .refused(.noWorktree(id: "w-00000000")))
    #expect(harness.model.workspace.tabs.isEmpty)
  }

  @Test func anAgentTabAskedForStartsThatAgentOnItsTask() async throws {
    let harness = Harness()
    harness.model.select(harness.main)

    _ = await harness.stateSource.ask(
      .newTab(order(ControlID.worktree(harness.main.id), agentID: "claude", task: "fix it"))
    )

    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    #expect(harness.model.workspace.session(tab.focusedSessionID)?.agentID == "claude")
    #expect(harness.engine.opened.last?.command?.last?.contains("fix it") == true)
  }

  @Test func aTabForAnAgentTheCatalogueLacksIsRefusedAndOpensNothing() async {
    let harness = Harness()
    harness.model.select(harness.main)
    let before = harness.model.workspace.tabs.count
    let alertBefore = harness.model.presentedError?.id

    let reply = await harness.stateSource.ask(
      .newTab(order(ControlID.worktree(harness.main.id), agentID: "bogus"))
    )

    #expect(reply == .refused(.noAgent(id: "bogus")))
    #expect(harness.model.workspace.tabs.count == before)
    #expect(harness.model.presentedError?.id == alertBefore)
  }

  @Test func aTabForAnAgentThatIsNotInstalledIsRefusedAndOpensNothing() async {
    let harness = Harness()
    harness.model.loginEnvironment = LoginShellEnvironment(
      variables: ["PATH": "/usr/bin"],
      source: .loginShell(URL(fileURLWithPath: "/bin/zsh")),
    )
    harness.model.agentDetection = AgentDetection(searchPath: "/usr/bin")
    harness.model.select(harness.main)
    let before = harness.model.workspace.tabs.count

    let reply = await harness.stateSource.ask(
      .newTab(order(ControlID.worktree(harness.main.id), agentID: AgentCatalogue.claudeID))
    )

    #expect(reply == .refused(.agentNotInstalled(id: AgentCatalogue.claudeID)))
    #expect(harness.model.workspace.tabs.count == before)
  }
}
