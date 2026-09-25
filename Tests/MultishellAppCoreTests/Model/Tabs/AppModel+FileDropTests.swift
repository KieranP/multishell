import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelFileDropTests {
  @Test func filesDroppedOnAShellArriveAsQuotedPaths() {
    let h = Harness()
    h.model.select(h.main)
    let session = h.model.workspace.sessions(in: h.main.id)[0]

    let dropped = h.model.dropFiles(
      [h.main.path.appendingPathComponent("a.swift")], into: session.id)

    #expect(dropped)
    #expect(h.engine.pasted.count == 1)
    #expect(h.engine.pasted[0].id == session.id)
    #expect(h.engine.pasted[0].text == "\(h.main.path.path)/a.swift ")
  }

  @Test func filesDroppedOnAClaudeCodeTabArriveAsMentions() {
    let h = Harness()
    h.model.select(h.main)
    h.store.openTab(in: h.main.id, title: "Claude Code", agentID: AgentCatalogue.claudeID)
    h.model.reconcileSessions(takingFocus: true)
    guard let session = h.model.workspace.sessions(in: h.main.id).last else {
      return #expect(Bool(false), "the agent tab has a session")
    }

    let dropped = h.model.dropFiles(
      [
        h.main.path.appendingPathComponent("Sources/App.swift"),
        h.main.path.appendingPathComponent("README.md"),
      ], into: session.id)

    #expect(dropped)
    #expect(h.engine.pasted.map(\.text) == ["@Sources/App.swift @README.md "])
  }

  /// The common case: the user types `claude` at a plain shell prompt, so
  /// the tab has no agent id and the hooks are what say who is there.
  @Test func filesDroppedOnAnAgentStartedByHandArriveAsMentions() {
    let h = Harness()
    h.model.select(h.main)
    let session = h.model.workspace.sessions(in: h.main.id)[0]
    #expect(session.agentID == nil, "a plain shell tab")

    h.source.send(
      SessionStateReport(
        state: .idle, sessionID: session.id, pid: ProcessInfo.processInfo.processIdentifier,
        agent: AgentCatalogue.claudeID))
    h.model.dropFiles(
      [h.main.path.appendingPathComponent("Sources/App.swift")], into: session.id)

    #expect(h.engine.pasted.map(\.text) == ["@Sources/App.swift "])
  }

  /// And when it quits, the prompt is the shell's again. Claude's hooks
  /// report its own pid, so a pid that has left the table is the signal.
  @Test func anAgentThatHasQuitLeavesThePaneAPlainShell() {
    let h = Harness()
    h.model.select(h.main)
    let session = h.model.workspace.sessions(in: h.main.id)[0]

    // Above the highest pid the kernel hands out, so it is certainly gone.
    h.source.send(
      SessionStateReport(
        state: .done, sessionID: session.id, pid: 999_999, agent: AgentCatalogue.claudeID))
    h.model.dropFiles([h.main.path.appendingPathComponent("a.swift")], into: session.id)

    #expect(h.engine.pasted.map(\.text) == ["\(h.main.path.path)/a.swift "])
  }

  @Test func anAgentThisBuildDoesNotKnowGetsAPlainPath() {
    let h = Harness()
    h.model.select(h.main)
    let session = h.model.workspace.sessions(in: h.main.id)[0]

    h.source.send(
      SessionStateReport(
        state: .running, sessionID: session.id,
        pid: ProcessInfo.processInfo.processIdentifier, agent: "future-agent"))
    h.model.dropFiles([h.main.path.appendingPathComponent("a.swift")], into: session.id)

    #expect(h.engine.pasted.map(\.text) == ["\(h.main.path.path)/a.swift "])
  }

  @Test func aDropFocusesThePaneItLandedIn() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.sessions(in: h.main.id)[0].id
    h.model.splitActivePane(.horizontal)
    guard let second = h.model.workspace.activeTab(in: h.main.id)?.focusedSessionID,
      second != first
    else { return #expect(Bool(false), "the split made a second pane and focused it") }

    h.model.dropFiles([h.main.path.appendingPathComponent("a.swift")], into: first)

    #expect(h.model.workspace.activeTab(in: h.main.id)?.focusedSessionID == first)
    #expect(h.engine.focused.last == first)
  }

  /// A promised drag's files land after the drop, when the user may have moved on. Taking
  /// the focus then would switch the worktree's tab and save that.
  @Test func aDropWhoseFilesArrivedLateDoesNotTakeTheFocusBack() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.sessions(in: h.main.id)[0].id
    h.model.splitActivePane(.horizontal)
    guard let second = h.model.workspace.activeTab(in: h.main.id)?.focusedSessionID,
      second != first
    else { return #expect(Bool(false), "the split made a second pane and focused it") }

    let dropped = h.model.dropFiles(
      [h.main.path.appendingPathComponent("a.swift")], into: first, takingFocus: false)

    #expect(dropped, "the files are still pasted where they were dropped")
    #expect(h.engine.pasted.last?.id == first)
    #expect(h.model.workspace.activeTab(in: h.main.id)?.focusedSessionID == second)
    #expect(h.engine.focused.last != first)
  }

  @Test func aDropOnATabWithNoShellRunningIsRefused() {
    let h = Harness()
    // A tab in a worktree that has never been visited has no shell: nothing
    // is warm until it is selected.
    guard let tab = h.store.openTab(in: h.feature.id) else {
      return #expect(Bool(false), "the tab opened")
    }
    let session = tab.focusedSessionID

    let dropped = h.model.dropFiles(
      [h.feature.path.appendingPathComponent("a.swift")], into: session)

    #expect(!dropped)
    #expect(!h.model.acceptsFileDrop(into: session))
    #expect(h.engine.pasted.isEmpty)
  }

  @Test func aDropOfNoFilesIsRefused() {
    let h = Harness()
    h.model.select(h.main)
    let session = h.model.workspace.sessions(in: h.main.id)[0]
    #expect(!h.model.dropFiles([], into: session.id))
    #expect(
      !h.model.dropFiles([h.main.path.appendingPathComponent("two\nlines.md")], into: session.id),
      "a name a terminal would act on leaves nothing to paste")
    #expect(h.engine.pasted.isEmpty)
  }

  /// A session whose surface never came up takes no text, and the drag is told so rather
  /// than the files going nowhere.
  @Test func aDropTheEngineCouldNotTakeIsRefused() {
    let h = Harness()
    h.model.select(h.main)
    let session = h.model.workspace.sessions(in: h.main.id)[0]
    h.engine.openSessionIDs.remove(session.id)

    #expect(!h.model.dropFiles([h.main.path.appendingPathComponent("a.swift")], into: session.id))
    #expect(h.engine.pasted.isEmpty)
    #expect(
      h.model.workspace.activeTab(in: h.main.id)?.focusedSessionID == session.id,
      "and nothing else moved")
  }
}
