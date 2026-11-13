import Foundation
import Observation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellProcess

@MainActor
@Suite
struct AppModelReviewSendTests {
  private static func comment(_ text: String = "Guard it.") -> ReviewComment {
    ReviewComment(
      path: "Sources/App.swift",
      side: .onDisk,
      scope: .modified,
      lines: 3...4,
      quote: ["let a = 1"],
      text: text,
    )
  }

  /// The main worktree selected, with an agent tab for each id given.
  private static func harness(withAgents agentIDs: [String]) -> (Harness, [TerminalSession]) {
    let harness = Harness()
    harness.model.select(harness.main)
    for agentID in agentIDs {
      harness.store.openTab(in: harness.main.id, title: agentID, agentID: agentID)
    }
    harness.model.reconcileSessions(takingFocus: true)
    let agents = harness.model.workspace.sessions(in: harness.main.id).filter { $0.agentID != nil }
    return (harness, agents)
  }

  /// Spelled from `drops` as given, a listing naming the temporary directory's `/private` target.
  private static func handoffFiles(in drops: URL) -> [URL] {
    let manager = FileManager.default
    let directories = (try? manager.contentsOfDirectory(atPath: drops.path)) ?? []
    return directories.flatMap { name in
      let directory = drops.appendingPathComponent(name, isDirectory: true)
      return ((try? manager.contentsOfDirectory(atPath: directory.path)) ?? []).map { file in
        directory.appendingPathComponent(file, isDirectory: false)
      }
    }
  }

  @Test func claudeCodeIsHandedAMentionOfTheReviewFileWithItsSpacesEscaped() throws {
    let (harness, agents) = Self.harness(withAgents: [AgentCatalogue.claudeID])
    let drops = harness.drops
    harness.model.addReviewComment(Self.comment(), in: harness.main.id)

    let sent = harness.model.sendReviewToPickedAgent(of: harness.main)

    #expect(sent)
    let file = try #require(Self.handoffFiles(in: drops).first)
    let escaped = file.path.replacingOccurrences(of: " ", with: "\\ ")
    #expect(harness.engine.pasted.map(\.id) == [agents[0].id])
    #expect(harness.engine.pasted.map(\.text) == ["@\(escaped) "])
    #expect(file.lastPathComponent == "review-main.md")
  }

  @Test func anAgentWithNoMentionsIsHandedASentenceAroundTheQuotedPath() throws {
    let (harness, _) = Self.harness(withAgents: [AgentCatalogue.codexID])
    harness.model.addReviewComment(Self.comment(), in: harness.main.id)

    harness.model.sendReviewToPickedAgent(of: harness.main)

    let file = try #require(Self.handoffFiles(in: harness.model.dropsDirectory).first)
    let quoted = AnyShellQuoting.quote(file.path)
    #expect(harness.engine.pasted.map(\.text) == ["Address the review comments in \(quoted) "])
  }

  @Test func sendingMarksEveryPendingCommentSentToTheAgent() {
    let (harness, _) = Self.harness(withAgents: [AgentCatalogue.claudeID])
    harness.model.addReviewComment(Self.comment("one"), in: harness.main.id)
    harness.model.addReviewComment(Self.comment("two"), in: harness.main.id)

    harness.model.sendReviewToPickedAgent(of: harness.main)

    let states = harness.model.reviewComments(in: harness.main.id).map(\.state)
    #expect(states.allSatisfy { if case .sent("Claude Code", _) = $0 { true } else { false } })
    #expect(
      harness.model.reviewSendReceipts[harness.main.id]?.summary == "2 comments sent to Claude Code"
    )
  }

  @Test func aPasteThePaneRefusesMarksNothingSentAndLeavesNoFile() throws {
    let (harness, agents) = Self.harness(withAgents: [AgentCatalogue.claudeID])
    harness.model.addReviewComment(Self.comment(), in: harness.main.id)
    harness.engine.liveSessionIDs.remove(agents[0].id)

    let sent = harness.model.sendReview(of: harness.main.id, to: agents[0].id, takingFocus: true)

    #expect(!sent)
    #expect(harness.model.reviewComments(in: harness.main.id).allSatisfy { $0.isPending })
    #expect(Self.handoffFiles(in: harness.model.dropsDirectory).isEmpty)
  }

  @Test func sendGoesToTheAgentThePickerShowedOrNowhereOnceItsPaneCloses() throws {
    let (harness, agents) = Self.harness(withAgents: [
      AgentCatalogue.claudeID, AgentCatalogue.codexID,
    ])
    harness.model.addReviewComment(Self.comment(), in: harness.main.id)
    harness.model.pickReviewRecipient(agents[0].id, in: harness.main.id)
    guard case .ready(let picked, _, _) = harness.model.reviewFooter(of: harness.main) else {
      Issue.record("the footer offers the agent")
      return
    }
    let claudeTab = try #require(harness.model.workspace.tab(owning: picked.id))

    harness.model.closeTab(claudeTab.id)
    let sent = harness.model.sendReview(of: harness.main.id, to: picked.id, takingFocus: true)

    #expect(!sent)
    #expect(harness.engine.pasted.isEmpty)
    #expect(harness.model.reviewComments(in: harness.main.id).allSatisfy { $0.isPending })
  }

  @Test func withNothingPendingSendIsOffAndSendsNothing() {
    let (harness, _) = Self.harness(withAgents: [AgentCatalogue.claudeID])

    guard case .ready(_, _, let canSend) = harness.model.reviewFooter(of: harness.main) else {
      Issue.record("the footer offers the agent")
      return
    }
    #expect(!canSend)
    #expect(!harness.model.sendReviewToPickedAgent(of: harness.main))
    #expect(harness.engine.pasted.isEmpty)
  }

  @Test func withNoAgentInTheWorktreeSendIsOff() {
    let (harness, _) = Harness.withOnePane()
    harness.model.addReviewComment(Self.comment(), in: harness.main.id)

    #expect(harness.model.reviewRecipients(in: harness.main.id).isEmpty)
    #expect(harness.model.reviewFooter(of: harness.main) == .noRecipient("No agent in main"))
  }

  @Test func theAgentFocusedLastIsWhereAReviewGoesUnlessOneIsPicked() {
    let (harness, agents) = Self.harness(withAgents: [
      AgentCatalogue.claudeID, AgentCatalogue.codexID,
    ])
    let claude = agents[0].id
    let codex = agents[1].id

    harness.model.reconciler.terminalHost(harness.engine, didFocus: codex)
    harness.model.reconciler.terminalHost(harness.engine, didFocus: claude)
    #expect(harness.model.reviewRecipient(in: harness.main.id)?.id == claude)

    harness.model.pickReviewRecipient(codex, in: harness.main.id)
    #expect(harness.model.reviewRecipient(in: harness.main.id)?.id == codex)
  }

  @Test func addingACommentClearsWhatTheLastSendSaid() {
    let (harness, _) = Self.harness(withAgents: [AgentCatalogue.claudeID])
    harness.model.addReviewComment(Self.comment(), in: harness.main.id)
    harness.model.sendReviewToPickedAgent(of: harness.main)

    harness.model.addReviewComment(Self.comment("next"), in: harness.main.id)

    #expect(harness.model.reviewSendReceipts[harness.main.id] == nil)
  }

  @Test func focusingAnotherAgentRedrawsThePickerThatDefaultsToIt() {
    let (harness, agents) = Self.harness(withAgents: [
      AgentCatalogue.claudeID, AgentCatalogue.codexID,
    ])
    harness.model.addReviewComment(Self.comment(), in: harness.main.id)
    let changed = AtomicFlag()
    withObservationTracking {
      _ = harness.model.reviewFooter(of: harness.main)
    } onChange: {
      changed.raise()
    }

    harness.model.noteSessionFocused(agents[1].id)

    #expect(changed.raised)
  }

  @Test func anAgentStartedFromACustomCommandIsSentASentenceAroundThePath() throws {
    let (harness, agents) = Self.harness(withAgents: [AgentCatalogue.customID])
    harness.model.addReviewComment(Self.comment(), in: harness.main.id)
    let recipient = try #require(harness.model.reviewRecipient(in: harness.main.id))

    let sent = harness.model.sendReviewToPickedAgent(of: harness.main)

    #expect(recipient.id == agents.first?.id)
    #expect(sent)
    let pasted = try #require(harness.engine.pasted.last?.text)
    #expect(pasted.hasPrefix("Address the review comments in "))
    #expect(harness.model.reviewComments(in: harness.main.id).first?.isPending == false)
  }
}
