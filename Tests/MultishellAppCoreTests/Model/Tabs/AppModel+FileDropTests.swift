import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelFileDropTests {
  @Test func filesDroppedOnAShellArriveAsQuotedPaths() {
    let harness = Harness()
    harness.model.select(harness.main)
    let session = harness.model.workspace.sessions(in: harness.main.id)[0]

    let dropped = harness.model.dropFiles(
      [harness.main.path.appendingPathComponent("a.swift")], into: session.id)

    #expect(dropped)
    #expect(harness.engine.pasted.count == 1)
    #expect(harness.engine.pasted[0].id == session.id)
    #expect(harness.engine.pasted[0].text == "\(harness.main.path.path)/a.swift ")
  }

  @Test func filesDroppedOnAClaudeCodeTabArriveAsMentions() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.store.openTab(
      in: harness.main.id, title: "Claude Code", agentID: AgentCatalogue.claudeID)
    harness.model.reconcileSessions(takingFocus: true)
    guard let session = harness.model.workspace.sessions(in: harness.main.id).last else {
      return #expect(Bool(false), "the agent tab has a session")
    }

    let dropped = harness.model.dropFiles(
      [
        harness.main.path.appendingPathComponent("Sources/App.swift"),
        harness.main.path.appendingPathComponent("README.md"),
      ], into: session.id)

    #expect(dropped)
    #expect(harness.engine.pasted.map(\.text) == ["@Sources/App.swift @README.md "])
  }

  /// The common case: the user types `claude` at a plain shell prompt, so
  /// the tab has no agent id and the hooks are what say who is there.
  @Test func filesDroppedOnAnAgentStartedByHandArriveAsMentions() {
    let harness = Harness()
    harness.model.select(harness.main)
    let session = harness.model.workspace.sessions(in: harness.main.id)[0]
    #expect(session.agentID == nil, "a plain shell tab")

    harness.stateSource.send(
      SessionStateReport(
        state: .idle, sessionID: session.id, pid: ProcessInfo.processInfo.processIdentifier,
        agentID: AgentCatalogue.claudeID))
    harness.model.dropFiles(
      [harness.main.path.appendingPathComponent("Sources/App.swift")], into: session.id)

    #expect(harness.engine.pasted.map(\.text) == ["@Sources/App.swift "])
  }

  /// And when it quits, the prompt is the shell's again. Claude's hooks
  /// report its own pid, so a pid that has left the table is the signal.
  @Test func anAgentThatHasQuitLeavesThePaneAPlainShell() {
    let harness = Harness()
    harness.model.select(harness.main)
    let session = harness.model.workspace.sessions(in: harness.main.id)[0]

    harness.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session.id, pid: deadPID(), agentID: AgentCatalogue.claudeID))
    harness.model.dropFiles([harness.main.path.appendingPathComponent("a.swift")], into: session.id)

    #expect(harness.engine.pasted.map(\.text) == ["\(harness.main.path.path)/a.swift "])
  }

  @Test func anAgentThisBuildDoesNotKnowGetsAPlainPath() {
    let harness = Harness()
    harness.model.select(harness.main)
    let session = harness.model.workspace.sessions(in: harness.main.id)[0]

    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session.id,
        pid: ProcessInfo.processInfo.processIdentifier, agentID: "future-agent"))
    harness.model.dropFiles([harness.main.path.appendingPathComponent("a.swift")], into: session.id)

    #expect(harness.engine.pasted.map(\.text) == ["\(harness.main.path.path)/a.swift "])
  }

  @Test func aDropFocusesThePaneItLandedIn() {
    let harness = Harness()
    harness.model.select(harness.main)
    let first = harness.model.workspace.sessions(in: harness.main.id)[0].id
    harness.model.splitActivePane(.horizontal)
    guard let second = harness.model.workspace.activeTab(in: harness.main.id)?.focusedSessionID,
      second != first
    else { return #expect(Bool(false), "the split made a second pane and focused it") }

    harness.model.dropFiles([harness.main.path.appendingPathComponent("a.swift")], into: first)

    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.focusedSessionID == first)
    #expect(harness.engine.focused.last == first)
  }

  /// A promised drag's files land after the drop, when the user may have moved on. Taking
  /// the focus then would switch the worktree's tab and save that.
  @Test func aDropWhoseFilesArrivedLateDoesNotTakeTheFocusBack() {
    let harness = Harness()
    harness.model.select(harness.main)
    let first = harness.model.workspace.sessions(in: harness.main.id)[0].id
    harness.model.splitActivePane(.horizontal)
    guard let second = harness.model.workspace.activeTab(in: harness.main.id)?.focusedSessionID,
      second != first
    else { return #expect(Bool(false), "the split made a second pane and focused it") }

    let dropped = harness.model.dropFiles(
      [harness.main.path.appendingPathComponent("a.swift")], into: first, takingFocus: false)

    #expect(dropped, "the files are still pasted where they were dropped")
    #expect(harness.engine.pasted.last?.id == first)
    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.focusedSessionID == second)
    #expect(harness.engine.focused.last != first)
  }

  @Test func aDropOnATabWithNoShellRunningIsRefused() {
    let harness = Harness()
    // A tab in a worktree that has never been visited has no shell: nothing
    // is warm until it is selected.
    guard let tab = harness.store.openTab(in: harness.feature.id) else {
      return #expect(Bool(false), "the tab opened")
    }
    let session = tab.focusedSessionID

    let dropped = harness.model.dropFiles(
      [harness.feature.path.appendingPathComponent("a.swift")], into: session)

    #expect(!dropped)
    #expect(!harness.model.acceptsFileDrop(into: session))
    #expect(harness.engine.pasted.isEmpty)
  }

  @Test func aDropOfNoFilesOrOnlyUnpastableNamesIsRefused() {
    let harness = Harness()
    harness.model.select(harness.main)
    let session = harness.model.workspace.sessions(in: harness.main.id)[0]
    #expect(!harness.model.dropFiles([], into: session.id))
    #expect(
      !harness.model.dropFiles(
        [harness.main.path.appendingPathComponent("two\nlines.md")], into: session.id),
      "a name a terminal would act on leaves nothing to paste")
    #expect(harness.engine.pasted.isEmpty)
  }

  /// A session whose surface never came up takes no text, and the drag is told so rather
  /// than the files going nowhere.
  @Test func aDropTheEngineCouldNotTakeIsRefused() {
    let harness = Harness()
    harness.model.select(harness.main)
    let session = harness.model.workspace.sessions(in: harness.main.id)[0]
    harness.engine.liveSessionIDs.remove(session.id)

    #expect(
      !harness.model.dropFiles(
        [harness.main.path.appendingPathComponent("a.swift")], into: session.id))
    #expect(harness.engine.pasted.isEmpty)
    #expect(
      harness.model.workspace.activeTab(in: harness.main.id)?.focusedSessionID == session.id,
      "and nothing else moved")
  }
}
