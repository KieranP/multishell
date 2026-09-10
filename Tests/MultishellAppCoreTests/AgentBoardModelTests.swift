import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// What the model does around the board: what it gathers, what showing it
/// means for a Done state, and the badge.
@Suite
@MainActor
struct AgentBoardModelTests {
  /// A worktree with one live pane, and the session behind it.
  private func harnessWithOnePane() -> (Harness, TerminalSession) {
    let harness = Harness()
    harness.model.select(harness.main)
    let session = harness.store.workspace.sessions[0]
    return (harness, session)
  }

  @Test func aPlainShellIsGatheredButOnlyAnAgentIsOnTheBoard() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model

    #expect(model.agentBoardCards.count == 1)
    #expect(!model.agentBoardCards[0].occupant.isAgent)
    #expect(model.agentBoard.isEmpty, "a shell is not an agent")

    model.setShowsAllTerminals(true)
    #expect(model.agentBoard.cardCount == 1)
    #expect(model.agentBoard.count(of: .idle) == 1)

    // An agent reports from that shell, so the pane is one from now on.
    harness.source.send(SessionStateReport(state: .running, sessionID: session.id, agent: "claude"))
    model.setShowsAllTerminals(false)
    #expect(model.agentBoard.count(of: .working) == 1)
    #expect(model.agentBoard.column(.working).cards[0].occupant == .agent("Claude Code"))
  }

  /// One card per pane, not per tab: a split holds two panes under one
  /// strip and each is something an agent could be sitting in.
  @Test func aSplitTabIsTwoCards() {
    let (harness, _) = harnessWithOnePane()
    let model = harness.model
    model.setShowsAllTerminals(true)
    #expect(model.agentBoard.cardCount == 1)

    model.splitActivePane(.horizontal)
    #expect(model.agentBoard.cardCount == 2)

    let cards = model.agentBoard.column(.idle).cards
    #expect(Set(cards.map(\.tabID)).count == 1, "the same tab")
    #expect(Set(cards.map(\.id)).count == 2, "two panes in it")
  }

  /// A tab opened to run an agent is an agent pane before any hook fires,
  /// so a machine with no hooks installed still gets a board.
  @Test func aTabOpenedForAnAgentCountsBeforeItHasReported() {
    let harness = Harness()
    let model = harness.model
    model.setPreferredAgent(AgentCatalogue.customID)
    model.setCustomAgentCommand("my-agent")
    model.select(harness.main)
    model.newAgentTab()

    let agentCards = model.agentBoardCards.filter(\.occupant.isAgent)
    #expect(agentCards.count == 1)
    #expect(agentCards[0].occupant == .agent("Custom command"))
    #expect(model.agentBoard.count(of: .idle) == 1, "nothing has reported from it yet")
  }

  @Test func aCardCarriesWhereItIsAndWhatItLastSaid() {
    let (harness, session) = harnessWithOnePane()
    harness.source.send(
      SessionStateReport(
        state: .attention, sessionID: session.id, message: "Permission to run rm -rf .build",
        agent: "claude"))

    let card = harness.model.agentBoard.column(.waiting).cards[0]
    #expect(card.projectName == harness.store.workspace.projects[0].name)
    #expect(card.worktreeName == harness.store.workspace.displayName(of: harness.main))
    #expect(card.message == "Permission to run rm -rf .build")
    #expect(card.since != nil)
  }

  /// Without this the selected worktree's Done states clear the moment the
  /// board opens, and their cards sit in Idle having never passed through
  /// Done: nothing would ever say a pane had finished.
  @Test func theBoardIsNotShowingATabSoADoneSurvivesOpeningIt() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model
    #expect(model.isShown(session.id))

    model.showAgentBoard()
    #expect(!model.isShown(session.id))

    model.setShowsAllTerminals(true)
    harness.source.send(SessionStateReport(state: .done, sessionID: session.id))
    #expect(model.agentBoard.count(of: .done) == 1)

    // Clicking through shows the pane, which is what clears a Done. The
    // card does not go anywhere: it moves to Idle.
    model.open(model.agentBoard.column(.done).cards[0])
    #expect(!model.showsAgentBoard)
    #expect(model.agentBoard.count(of: .done) == 0)
    #expect(model.agentBoard.count(of: .idle) == 1)
  }

  @Test func openingACardTurnsToItsPaneAndLeavesTheBoard() {
    let harness = Harness()
    harness.model.select(harness.feature)
    let session = harness.store.workspace.sessions[0]
    let model = harness.model
    model.setShowsAllTerminals(true)
    model.select(harness.main)
    model.showAgentBoard()

    let card = model.agentBoard.column(.idle).cards.first { $0.id == session.id }
    #expect(card != nil)
    model.open(card!)

    #expect(!model.showsAgentBoard)
    #expect(model.workspace.selectedWorktreeID == harness.feature.id)
    #expect(model.workspace.activeTab(in: harness.feature.id)?.id == card?.tabID)
    #expect(harness.engine.focused.last == session.id)
  }

  @Test func selectingAWorktreeLeavesTheBoard() {
    let harness = Harness()
    harness.model.showAgentBoard()
    #expect(harness.model.showsAgentBoard)
    harness.model.select(harness.feature)
    #expect(!harness.model.showsAgentBoard)
  }

  /// The sidebar entry and the badge count without building a card, so a
  /// shell reporting a new prompt does not re-render the sidebar. Two paths,
  /// one answer.
  @Test func theCheapCountsAgreeWithTheColumnsTheySummarise() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model
    model.showAgentBoard()

    for state in [SessionState.attention, .running, .done, .error, .idle] {
      for shells in [false, true] {
        model.setShowsAllTerminals(shells)
        harness.source.send(
          SessionStateReport(state: state, sessionID: session.id, agent: "claude"))
        let board = model.agentBoard
        for lane in AgentBoardLane.allCases {
          #expect(
            model.agentLaneCounts[lane] ?? 0 == board.count(of: lane),
            "\(lane) after \(state), shells \(shells)")
        }
      }
    }
  }

  @Test func theBadgeCountsTheWaitingColumnAndClearsWithIt() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model
    // With the board up rather than the pane: a Failed about a pane the user
    // is looking at has been seen already and never reaches a column.
    model.showAgentBoard()
    harness.platform.badges.removeAll()

    harness.source.send(
      SessionStateReport(state: .attention, sessionID: session.id, agent: "claude"))
    #expect(harness.platform.badges.last == 1)

    // A failure waits with the rest, so the badge does not move.
    harness.source.send(SessionStateReport(state: .error, sessionID: session.id, agent: "claude"))
    #expect(model.agentBoard.count(of: .waiting) == 1)
    #expect(harness.platform.badges == [1], "one waiting, still")

    harness.source.send(SessionStateReport(state: .running, sessionID: session.id, agent: "claude"))
    #expect(harness.platform.badges.last == .some(nil), "nothing waiting is no badge at all")
  }

  @Test func theBadgeFollowsTheFilter() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model
    model.showAgentBoard()
    harness.platform.badges.removeAll()

    harness.source.send(SessionStateReport(state: .error, sessionID: session.id))
    #expect(harness.platform.badges.isEmpty, "a shell, and shells are hidden")

    model.setShowsAllTerminals(true)
    #expect(harness.platform.badges.last == 1)
  }

  /// An agent killed with Ctrl+C sends no Stop. Once its process is gone the
  /// pane is a plain shell again, and with the filter off its card leaves.
  @Test func aGoneAgentTakesItsCardWithIt() async {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model
    model.pidPollInterval = .milliseconds(10)

    let gone = Self.pidOfADeadProcess()
    harness.source.send(
      SessionStateReport(state: .running, sessionID: session.id, pid: gone, agent: "claude"))
    #expect(model.agentBoard.count(of: .working) == 1)
    #expect(model.watchedPIDs.contains(gone))

    try? await Task.sleep(for: .seconds(2))
    #expect(model.agentBoard.isEmpty, "the pane is a shell again")
    #expect(model.reportedAgents[session.id] == nil)
  }

  /// A hook that fires in a terminal Multishell did not open reports a
  /// directory, not a session. It still moves the sidebar dot, but it has no
  /// pane to take you to, so it earns no card and is not in the badge. The
  /// board is deliberately narrower than the sidebar here.
  @Test func aReportWithNoPaneBehindItEarnsNoCard() {
    let harness = Harness()
    let model = harness.model
    model.select(harness.main)
    model.setShowsAllTerminals(true)
    model.showAgentBoard()
    let cards = model.agentBoard.cardCount

    harness.source.send(
      SessionStateReport(state: .attention, cwd: harness.feature.path.path, agent: "claude"))

    #expect(model.state(ofWorktree: harness.feature.id) == .attention, "the sidebar dot moves")
    #expect(model.agentBoard.cardCount == cards, "and nothing else does")
    #expect(model.agentBoard.count(of: .waiting) == 0)
    #expect(harness.platform.badges.last != 1)
  }

  /// `markShownTabSeen` runs from every `sync` and from a shell exiting, so
  /// without its own guard a close anywhere would clear a Done in the
  /// selected worktree — a pane the board is covering — and its card would
  /// jump to Idle under the user.
  @Test func aCloseElsewhereDoesNotClearADoneTheBoardIsShowing() {
    let harness = Harness()
    let model = harness.model
    model.select(harness.feature)
    let elsewhere = harness.store.workspace.sessions[0]
    model.select(harness.main)
    let watched = harness.store.workspace.sessions.first { $0.id != elsewhere.id }
    #expect(watched != nil)

    model.setShowsAllTerminals(true)
    model.showAgentBoard()
    harness.source.send(SessionStateReport(state: .done, sessionID: watched!.id))
    #expect(model.agentBoard.count(of: .done) == 1)

    // A tab in the other worktree closes, which reconciles and marks
    // whatever is on screen as seen. Nothing is on screen.
    model.closeTab(harness.store.workspace.tabOwning(elsewhere.id)!.id)
    #expect(model.agentBoard.count(of: .done) == 1, "nobody looked at it")

    // Leaving the board is what clears it.
    model.hideAgentBoard()
    #expect(model.agentBoard.count(of: .done) == 0)
  }

  /// An agent that has gone quiet is watched only while the board is up:
  /// nothing else shows a quit agent, and a dropped file asks about the pid
  /// at the moment of the drop. So opening the board sweeps once, or its
  /// first frame would be stale.
  @Test func openingTheBoardSweepsAnAgentThatWentQuietAndQuit() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model
    let gone = Self.pidOfADeadProcess()

    harness.source.send(
      SessionStateReport(state: .running, sessionID: session.id, pid: gone, agent: "claude"))
    harness.source.send(
      SessionStateReport(state: .idle, sessionID: session.id, pid: gone, agent: "claude"))
    #expect(model.reportedAgents[session.id] != nil)
    #expect(!model.watchedPIDs.contains(gone), "nothing is being said about it")

    model.showAgentBoard()
    #expect(model.reportedAgents[session.id] == nil)
    #expect(model.agentBoard.isEmpty)
  }

  /// Cmd+W with the board up would otherwise end a shell in a pane nobody
  /// can see, and Cmd+T open a tab that appears only once the board is left.
  @Test func aKeystrokeAboutTheTerminalsDoesNothingBehindTheBoard() {
    let (harness, _) = harnessWithOnePane()
    let model = harness.model
    let tabs = model.workspace.tabs.count
    #expect(tabs == 1)

    model.showAgentBoard()
    model.newTab()
    model.newShellTab()
    model.splitActivePane(.horizontal)
    model.closeActivePane()
    model.closeActiveTab()
    model.moveActiveTabToNewGroup()
    model.selectNextTab()
    #expect(model.workspace.tabs.count == tabs, "nothing opened and nothing closed")
    #expect(model.workspace.sessions.count == 1)
    #expect(model.focusedGroup == nil)

    // And they work again the moment the panes are back.
    model.hideAgentBoard()
    model.newTab()
    #expect(model.workspace.tabs.count == tabs + 1)
  }

  /// A pid that has certainly been reaped: a child run to completion and
  /// waited for. Far cheaper than waiting out a real agent.
  private static func pidOfADeadProcess() -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
    try? process.run()
    process.waitUntilExit()
    return process.processIdentifier
  }
}
