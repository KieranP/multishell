import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
@MainActor
struct AppModelAgentBoardTests {
  @Test func aPlainShellIsGatheredButOnlyAnAgentIsOnTheBoard() {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model

    #expect(model.agentBoardCards.count == 1)
    #expect(!model.agentBoardCards[0].occupant.isAgent)
    #expect(model.agentBoard.isEmpty, "a shell is not an agent")

    model.setShowsAllTerminals(true)
    #expect(model.agentBoard.cardCount == 1)
    #expect(model.agentBoard.count(of: .idle) == 1)

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "claude")
    )
    model.setShowsAllTerminals(false)
    #expect(model.agentBoard.count(of: .working) == 1)
    #expect(
      model.agentBoard.column(.working).cards[0].occupant
        == .agent(id: "claude", name: "Claude Code")
    )
  }

  /// A split holds two panes under one strip, and an agent could be sitting
  /// in either.
  @Test func aSplitTabIsTwoCards() {
    let (harness, _) = Harness.withOnePane()
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
    #expect(agentCards[0].occupant == .agent(id: "custom", name: "Custom command"))
    #expect(model.agentBoard.count(of: .idle) == 1, "nothing has reported from it yet")
  }

  @Test func aCardCarriesWhereItIsAndWhatItLastSaid() {
    let (harness, session) = Harness.withOnePane()
    harness.stateSource.send(
      SessionStateReport(
        state: .attention,
        sessionID: session.id,
        message: "Permission to run rm -rf .build",
        agentID: "claude",
      )
    )

    let card = harness.model.agentBoard.column(.waiting).cards[0]
    #expect(card.projectName == harness.store.workspace.projects[0].name)
    #expect(card.worktreeName == harness.store.workspace.displayName(of: harness.main))
    #expect(card.message == "Permission to run rm -rf .build")
    #expect(card.since != nil)
  }

  /// Otherwise the selected worktree's Done states clear as the board opens, and nothing would
  /// ever say a pane had finished.
  @Test func aDoneArrivingUnderTheBoardStaysUntilItsCardIsOpened() {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model
    #expect(model.isPaneInView(session.id))

    model.showAgentBoard()
    #expect(!model.isPaneInView(session.id))

    model.setShowsAllTerminals(true)
    harness.stateSource.send(SessionStateReport(state: .done, sessionID: session.id))
    #expect(model.agentBoard.count(of: .done) == 1)

    model.show(model.agentBoard.column(.done).cards[0])
    #expect(!model.showsAgentBoard)
    #expect(model.agentBoard.count(of: .done) == 0)
    #expect(model.agentBoard.count(of: .idle) == 1)
  }

  /// The sidebar entry and the badge count without building a card, so a shell reporting a new
  /// prompt does not re-render the sidebar.
  @Test func theCheapCountsAgreeWithTheColumnsTheySummarise() {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model
    model.showAgentBoard()

    for state in [SessionState.attention, .running, .done, .failed, .idle] {
      for shells in [false, true] {
        model.setShowsAllTerminals(shells)
        harness.stateSource.send(
          SessionStateReport(state: state, sessionID: session.id, agentID: "claude")
        )
        let board = model.agentBoard
        for lane in AgentBoardLane.allCases {
          #expect(
            model.boardLaneCounts[lane] ?? 0 == board.count(of: lane),
            "\(lane) after \(state), shells \(shells)",
          )
        }
      }
    }
  }

  @Test func theSidebarEntryCarriesOnlyTheLanesWithSomethingInThem() {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model
    #expect(model.sidebarLaneCounts.isEmpty)

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "claude")
    )
    #expect(model.sidebarLaneCounts == [AgentBoardLaneCount(.working, 1)])
  }

  /// An agent killed with Ctrl+C sends no Stop. Once its process is gone the
  /// pane is a plain shell again, and with the filter off its card leaves.
  @Test func aGoneAgentTakesItsCardWithIt() async throws {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model
    model.pidPollInterval = .milliseconds(10)

    let agent = Process()
    agent.executableURL = URL(fileURLWithPath: "/bin/sleep")
    agent.arguments = ["60"]
    try agent.run()
    let pid = agent.processIdentifier
    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, pid: pid, agentID: "claude")
    )
    #expect(model.agentBoard.count(of: .working) == 1)
    #expect(model.watchedPIDs.contains(pid))

    agent.terminate()
    agent.waitUntilExit()
    try await waitUntil { model.agentBoard.isEmpty }
    #expect(model.agentBoard.isEmpty, "the pane is a shell again")
    #expect(model.reportedAgents[session.id] == nil)
  }

  /// A hook in a terminal Multishell did not open reports a directory and has no pane to take you
  /// to; the board is narrower than the sidebar here on purpose.
  @Test func aReportWithNoPaneBehindItEarnsNoCard() {
    let harness = Harness()
    let model = harness.model
    model.select(harness.main)
    model.setShowsAllTerminals(true)
    model.showAgentBoard()
    let cards = model.agentBoard.cardCount

    harness.stateSource.send(
      SessionStateReport(
        state: .attention,
        workingDirectory: harness.feature.path.path,
        agentID: "claude",
      )
    )

    #expect(model.state(ofWorktree: harness.feature.id) == .attention, "the sidebar dot moves")
    #expect(model.agentBoard.cardCount == cards, "and nothing else does")
    #expect(model.agentBoard.count(of: .waiting) == 0)
    #expect(harness.platform.badges.last != 1)
  }

  /// `markInViewSeen` runs from every focus-taking reconcile and a shell
  /// exiting, so without its own guard a close anywhere clears a covered Done.
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
    harness.stateSource.send(SessionStateReport(state: .done, sessionID: watched!.id))
    #expect(model.agentBoard.count(of: .done) == 1)

    // A tab in the other worktree closes, which reconciles and marks
    // whatever is on screen as seen. Nothing is on screen.
    model.closeTab(harness.store.workspace.tab(owning: elsewhere.id)!.id)
    #expect(model.agentBoard.count(of: .done) == 1, "nobody looked at it")

    model.hideAgentBoard()
    #expect(model.agentBoard.count(of: .done) == 0)
  }

  /// Both panes of a renamed tab carry one name, so without a position the board draws two cards
  /// nothing tells apart.
  @Test func eachCardOfASplitSaysWhichPaneItIs() {
    let harness = Harness()
    let model = harness.model
    model.select(harness.main)
    let tab = model.workspace.activeTab(in: harness.main.id)!
    #expect(model.agentBoardCards.first { $0.id == tab.focusedSessionID }?.position == nil)

    model.splitActivePane(.horizontal)
    model.renameTab(tab.id, to: "build")
    let panes = model.workspace.tab(tab.id)!.sessionIDs
    #expect(panes.count == 2)
    let cards = panes.compactMap { id in model.agentBoardCards.first { $0.id == id } }
    #expect(cards.map(\.title) == ["build", "build"])
    #expect(
      cards.map(\.position) == [
        PanePosition(number: 1, count: 2), PanePosition(number: 2, count: 2),
      ]
    )
    #expect(AccessibilityText.card(cards[1], at: .now).contains(t("spoken.pane-position", 2, 2)))
  }

  @Test func aPaneWhoseReportedAgentExitedIsAShellToTheCountsAsToTheStrip() {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model
    let tab = harness.store.workspace.tabs[0]
    let gone = deadPID()

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, pid: gone, agentID: "claude")
    )
    harness.stateSource.send(
      SessionStateReport(state: .idle, sessionID: session.id, pid: gone, agentID: "claude")
    )
    #expect(model.reportedAgents[session.id] != nil)

    #expect(model.agentIDAtThePrompt(of: tab) == nil)
    #expect(model.agentIDAtThePrompt(of: session) == nil)
    #expect(model.boardLaneCounts.values.reduce(0, +) == 0)
    #expect(!model.agentBoardCards[0].occupant.isAgent)
  }

  @Test func theBoardIsBuiltOnceUntilSomethingItReadChanges() throws {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model
    model.setShowsAllTerminals(true)
    _ = model.agentBoard
    let builds = model.agentBoardBuilds

    _ = model.agentBoard
    #expect(model.agentBoardBuilds == builds)

    model.noteTitle("vim", of: session.id)
    #expect(model.agentBoard.column(.idle).cards.first?.title == "vim")
    #expect(model.agentBoardBuilds == builds + 1)
  }

  @Test func aViewHoldingTheCachedBoardIsToldWhenItChanges() throws {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model
    model.setShowsAllTerminals(true)
    _ = model.agentBoard
    let changed = AtomicFlag()

    withObservationTracking {
      _ = model.agentBoard
    } onChange: {
      changed.raise()
    }
    model.noteTitle("vim", of: session.id)

    #expect(changed.raised)
  }
}
