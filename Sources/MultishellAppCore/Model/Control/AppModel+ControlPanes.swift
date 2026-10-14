import Foundation
import MultishellCore

extension AppModel {
  /// The split menu item's on the tab named, or the tab in view. Answers the
  /// new pane, which the split hands the focus.
  func replyToSplitPane(_ axis: SplitAxis, inTab id: TerminalTab.ID?) -> ControlReply {
    if let id {
      let selected = replyToSelectTab(id)
      guard selected == .done else { return selected }
    }
    guard let before = tabInView else { return .refused(.nothingInView) }
    // The split looks for the directory itself, raising the alert this answers with.
    guard let worktree = worktreeInView, !isBusy(worktree.id) else {
      return .refused(.worktreeNotReady(id: ControlID.worktree(before.worktreeID)))
    }
    splitActivePane(axis)
    guard let after = workspace.tab(before.id), after.sessionIDs.count > before.sessionIDs.count
    else { return .refused(.nothingInView) }
    return .json(["pane": after.focusedSessionID])
  }

  func replyToSelectPane(_ id: TerminalSession.ID) -> ControlReply {
    guard let tab = workspace.tab(owning: id) else { return .refused(.noPane(id: id)) }
    if let refusal = bringIntoView(tab) { return .refused(refusal) }
    show(pane: id, in: tab)
    return .done
  }

  func replyToClosePane(_ id: TerminalSession.ID, force: Bool) -> ControlReply {
    guard let tab = workspace.tab(owning: id) else { return .refused(.noPane(id: id)) }
    if refusesOverWorkingAgent(in: [id], force: force) { return .refused(.agentWorking) }
    closeWithoutAsking(.pane(id), takingFocus: isWorktreeInView(of: tab))
    return .done
  }

  /// Keystrokes, not a paste, so a shell runs the line where Return follows;
  /// the pane keeps whatever had the keyboard.
  func replyToTypeIntoPane(
    _ text: String,
    pressingReturn: Bool,
    into id: TerminalSession.ID,
  ) -> ControlReply {
    if let refusal = refusalToReachPane(id) { return .refused(refusal) }
    guard host.type(text, pressingReturn: pressingReturn, into: id) else {
      return .refused(.paneNotLive(id: id))
    }
    return .done
  }

  /// As a drop or Cmd+V puts it: bracketed for a program that asked, so a
  /// newline in it waits at a prompt rather than running the line.
  func replyToPasteIntoPane(_ text: String, into id: TerminalSession.ID) -> ControlReply {
    if let refusal = refusalToReachPane(id) { return .refused(refusal) }
    guard host.paste(text, into: id) else { return .refused(.paneNotLive(id: id)) }
    return .done
  }

  /// Pressed in the pane whether or not it has the keyboard, as `type` is.
  func replyToPressKeys(_ keys: [ControlKey], in id: TerminalSession.ID) -> ControlReply {
    if let refusal = refusalToReachPane(id) { return .refused(refusal) }
    if let unknown = keys.first(where: { !$0.isKnown }) {
      return .refused(.noKey(name: unknown.key))
    }
    guard host.press(keys, in: id) else { return .refused(.paneNotLive(id: id)) }
    return .done
  }

  /// The screen as the engine holds it, not as drawn: a pane out of view
  /// reads as well as one on screen.
  func replyToReadPane(_ id: TerminalSession.ID, includingScrollback: Bool) -> ControlReply {
    if let refusal = refusalToReachPane(id) { return .refused(refusal) }
    guard let text = host.text(of: id, includingScrollback: includingScrollback) else {
      return .refused(.paneNotLive(id: id))
    }
    return .output(text)
  }

  /// Through `receive`, as a hook's report goes, and answered with what the
  /// pane then shows, so a test sees the report land.
  func replyToReportPaneState(_ report: SessionStateReport) -> ControlReply {
    guard let id = report.sessionID else {
      return .refused(.invalidValue(key: "session", value: ""))
    }
    if let refusal = refusalToReachLivePane(id) { return .refused(refusal) }
    receive(report)
    return replyToDescribePane(id)
  }
}
