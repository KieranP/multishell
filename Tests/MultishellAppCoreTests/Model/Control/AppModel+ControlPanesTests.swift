import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlPanesTests {
  @Test func selectingAPaneHandsItTheKeyboard() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let first = onlyPane.id
    harness.model.splitActivePane(.vertical)

    let reply = await harness.stateSource.ask(.selectPane(id: first))

    #expect(reply == .done)
    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.focusedSessionID == first)
    #expect(harness.engine.focused.last == first)
  }

  @Test func aSplitAnswersTheNewPaneWhichHasTheFocus() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))

    let reply = try #require(
      await harness.stateSource.ask(.splitPane(axis: .vertical, tab: tab.id))
    )

    let split = try #require(harness.model.workspace.tab(tab.id))
    #expect(split.sessionIDs.count == 2)
    #expect(reply.outputFields["pane"] as? String == split.focusedSessionID.uuidString)
    #expect(split.focusedSessionID != tab.focusedSessionID)
  }

  @Test func aSplitLooksForTheWorktreesDirectoryOnce() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let probed = Recorder<String>()
    harness.model.directoryProbe = DirectoryProbe { path in
      probed.record(path)
      return true
    }

    _ = await harness.stateSource.ask(.splitPane(axis: .vertical, tab: nil))

    #expect(probed.received == [harness.main.path.path])
  }

  @Test func aSplitWhereTheDirectoryIsGoneAnswersWithTheAlertAndTakesItDown() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.presentedError = nil
    harness.model.directoryProbe = DirectoryProbe { _ in false }

    let reply = try #require(
      await harness.stateSource.ask(.splitPane(axis: .vertical, tab: nil))
    )

    guard case .alert(let title, _)? = reply.refusal else {
      Issue.record("not an alert: \(reply)")
      return
    }
    #expect(title == PresentedError.worktreeDirectoryMissing("").title)
    #expect(harness.model.presentedError == nil)
    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.sessionIDs.count == 1)
  }

  @Test func aSplitWithNothingInViewIsRefused() async {
    let harness = Harness()

    #expect(
      await harness.stateSource.ask(.splitPane(axis: .horizontal, tab: nil))
        == .refused(.nothingInView)
    )
  }

  @Test func textTypedIntoAPaneIsKeystrokesWithReturnWhereAskedAndAColdPaneIsRefused() async throws
  {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id

    #expect(
      await harness.stateSource.ask(.typeIntoPane(id: pane, text: "make", pressingReturn: true))
        == .done
    )

    #expect(harness.engine.typed.map(\.text) == ["make\r"])
    #expect(harness.engine.pasted.isEmpty)
    harness.engine.close(pane)
    #expect(
      await harness.stateSource.ask(.typeIntoPane(id: pane, text: "x", pressingReturn: false))
        == .refused(.paneNotLive(id: pane))
    )
  }

  @Test func aPaneReadsItsScreenOrItsScrollbackTooAndAColdOneIsRefused() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id
    harness.engine.screens[pane] = (screen: "$ make\nok\n", scrollback: "earlier\n")

    #expect(
      await harness.stateSource.ask(.readPane(id: pane, includingScrollback: false))
        == .output("$ make\nok\n")
    )
    #expect(
      await harness.stateSource.ask(.readPane(id: pane, includingScrollback: true))
        == .output("earlier\n$ make\nok\n")
    )
    harness.engine.close(pane)
    #expect(
      await harness.stateSource.ask(.readPane(id: pane, includingScrollback: false))
        == .refused(.paneNotLive(id: pane))
    )
  }

  @Test func aReportedStateLandsAsAHooksWouldAndAnswersThePaneAsItThenIs() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    let pane = tab.focusedSessionID
    let report = SessionStateReport(state: .running, sessionID: pane, agentID: "claude")

    let reply = try #require(await harness.stateSource.ask(.reportPaneState(report)))

    #expect(reply.outputFields["state"] as? String == "running")
    #expect(harness.model.state(of: tab) == .running)
  }

  @Test func aReportForAPaneThatIsGoneOrColdIsRefused() async throws {
    let harness = Harness()
    let pane = try #require(harness.model.store.openTab(in: harness.feature.id)?.focusedSessionID)
    let gone = UUID()

    #expect(
      await harness.stateSource.ask(.reportPaneState(.init(state: .done, sessionID: gone)))
        == .refused(.noPane(id: gone))
    )
    #expect(
      await harness.stateSource.ask(.reportPaneState(.init(state: .done, sessionID: pane)))
        == .refused(.paneNotLive(id: pane))
    )
  }

  @Test func keysArePressedInThePaneAndAColdOneIsRefused() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id
    let keys = try #require(["ctrl-c", "escape"].map(ControlKey.init(parsing:)) as? [ControlKey])

    #expect(await harness.stateSource.ask(.pressKeys(id: pane, keys: keys)) == .done)
    #expect(harness.engine.pressed.map(\.keys) == [keys])
    let cold = try #require(harness.model.store.openTab(in: harness.feature.id)?.focusedSessionID)
    #expect(
      await harness.stateSource.ask(.pressKeys(id: cold, keys: keys))
        == .refused(.paneNotLive(id: cold))
    )
  }

  @Test func aPasteGoesThroughThePastePathNotKeystrokes() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id

    #expect(await harness.stateSource.ask(.pasteIntoPane(id: pane, text: "a\nb")) == .done)

    #expect(harness.engine.pasted.map(\.text) == ["a\nb"])
    #expect(harness.engine.typed.isEmpty)
  }

  @Test func aSplitInAWorktreeMidRemovalIsRefusedAsNotReady() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.worktreeOperations.begin(.removingWorktree, on: harness.main.id)

    #expect(
      await harness.stateSource.ask(.splitPane(axis: .vertical, tab: nil))
        == .refused(.worktreeNotReady(id: ControlID.worktree(harness.main.id)))
    )
  }

  @Test func aKeyTheHelperWouldNotHaveSentIsRefusedBeforeAnyKeyIsPressed() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let known = try #require(ControlKey(parsing: "a"))
    let unknown = try JSONDecoder().decode(
      ControlKey.self,
      from: Data(#"{"key":"f13","modifiers":[]}"#.utf8),
    )

    #expect(
      await harness.stateSource.ask(.pressKeys(id: onlyPane.id, keys: [known, unknown]))
        == .refused(.noKey(name: "f13"))
    )
    #expect(harness.engine.pressed.isEmpty)
  }
}
