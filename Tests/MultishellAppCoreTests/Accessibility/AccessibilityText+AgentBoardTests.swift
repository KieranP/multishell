import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AccessibilityTextAgentBoardTests {
  private let now = Date(timeIntervalSince1970: 1_000_000)

  private func card(
    occupant: AgentBoardCard.Occupant, state: SessionState?, secondsAgo: Double? = nil,
    note: SessionNote? = nil, status: WorktreeStatus? = nil
  ) -> AgentBoardCard {
    .sample(
      occupant: occupant, title: "claude — repairReferences", worktreeID: "/r",
      worktreeName: "agents-view", state: state,
      since: secondsAgo.map { now.addingTimeInterval(-$0) }, note: note, status: status)
  }

  @Test func aBoardCardReadsInTheOrderItIsDrawn() {
    var status = WorktreeStatus()
    status.unstaged = 3
    status.changedFiles = 3
    #expect(
      AccessibilityText.card(
        card(
          occupant: .agent(id: "claude", name: "Claude Code"), state: .attention, secondsAgo: 360,
          note: SessionNote(state: .attention, message: "Permission to run rm -rf .build"),
          status: status),
        at: now)
          == """
          Waiting for input, multishell, agents-view, +0 −0 · 3 modified, \
          claude — repairReferences, Claude Code, agent, for 6m, \
          Permission to run rm -rf .build
          """)

    #expect(
      AccessibilityText.card(card(occupant: .shell("zsh"), state: nil), at: now)
        == "Nothing running, multishell, agents-view, claude — repairReferences, zsh, shell",
      "no time to give, and nothing said")
  }

  @Test func theSidebarAgentsRowReadsItsCounts() {
    #expect(
      AccessibilityText.agentsRow([
        AgentBoardLaneCount(.waiting, 2), AgentBoardLaneCount(.working, 3),
      ])
        == "Agents, 2 waiting for you, 3 working")
    #expect(AccessibilityText.agentsRow([]) == "Agents, nothing running")
  }

  @Test func aTabRowAndACardSayHowManyWorkersAreOutAndTheChipSaysWhich() {
    let out = [
      Worker(id: "a", type: "Explore", since: now.addingTimeInterval(-72)),
      Worker(id: "b", type: nil, since: now.addingTimeInterval(-34)),
    ]
    var withWorkers = card(
      occupant: .agent(id: "claude", name: "Claude Code"), state: .running, secondsAgo: 60)
    withWorkers.workers = out
    #expect(
      AccessibilityText.card(withWorkers, at: now)
        == "Working, multishell, agents-view, claude — repairReferences, Claude Code, agent, "
        + "2 subagents, for 1m")

    #expect(AccessibilityText.workers(out) == "2 subagents, Explore, subagent")
    #expect(
      AccessibilityText.pane(
        title: "claude", position: nil, isFocusedPane: false, state: .running, workers: out,
        agentName: "Claude Code")
        == "claude, tab, Claude Code, agent, Working, 2 subagents")
    #expect(
      AccessibilityText.pane(
        title: "fix tests", position: PanePosition(number: 2, count: 2),
        isFocusedPane: true, state: nil, workers: [],
        agentName: nil)
        == "fix tests, pane 2 of 2, selected",
      "a renamed tab names every pane alike, so the position tells them apart")
  }
}
