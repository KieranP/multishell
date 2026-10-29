import Foundation
import MultishellCore

extension AppModel {
  /// A click on the file's Files panel row, by the same rule; in a worktree out
  /// of view it opens without switching, as `tabs open` does.
  func replyToOpenFileTab(_ path: String, in id: String) async -> ControlReply {
    guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    let opened = await openFileAsTab(path, in: worktree.id, as: .request)
    // Opened or not, the check built a listing the panel may not show.
    forgetUnreadPanelListings()
    guard let tab = opened else {
      let isGone = workspace.worktree(worktree.id) == nil
      return .refused(isGone ? .noWorktree(id: id) : .fileNotOpenable(path: path))
    }
    return .json(["tab": tab.id])
  }

  /// The bar's arrow. Queued for the tab's view, which the arrow needs on screen.
  func replyToStepToChange(_ direction: CycleDirection, in id: FileTab.ID) -> ControlReply {
    if let refusal = refusalToReachFileTabOnScreen(id) { return .refused(refusal) }
    // What the view said holds only until it takes a step queued since.
    guard changeStepRequests[id]?.isEmpty ?? true else {
      return .refused(.stepNotYetTaken(id: id))
    }
    // A view that has not yet said where it is takes the step on its first update.
    if let steps = fileTabChangeSteps[id], !steps.allows(direction) {
      return .refused(.noChangeThatWay(id: id))
    }
    stepToChange(direction, in: id)
    return .done
  }

  /// The bar over a file tab, as `panes find` works a pane's; the answer is the tab.
  /// Closing needs no view, so a bar left up over a tab since hidden still goes.
  func replyToFindInFileTab(_ action: FindBarAction, in id: FileTab.ID) async -> ControlReply {
    switch action {
    case .close:
      if let refusal = refusalToReachFileTab(id) { return .refused(refusal) }
      return endFind(in: id) ? replyToDescribeTab(id) : .refused(.noFindBar(id: id))

    case .open(let text):
      if let refusal = await refusalToFindOnRows(action, in: id) { return .refused(refusal) }
      openFind(on: text, in: id)

    case .next, .previous:
      if let refusal = await refusalToFindOnRows(action, in: id) { return .refused(refusal) }
      // A step over rows not yet in hand would move nothing and still answer.
      guard holdsContent(id) else { return .refused(.fileTabNotRead(id: id)) }
      action == .next ? findNext(in: id) : findPrevious(in: id)
    }
    return replyToDescribeTab(id)
  }

  /// Rows are read a turn after a show: the scheduled read is waited on, never
  /// doubled; one already running the helper waits out, asking a step again.
  private func refusalToFindOnRows(
    _ action: FindBarAction,
    in id: FileTab.ID,
  ) async
    -> ControlRefusal?
  {
    if let refusal = refusalToReachFileTabOnScreen(id) ?? refusalToFind(action, in: id) {
      return refusal
    }
    guard !holdsContent(id), !fileTabReadLog.isReading(id) else { return nil }
    if let scheduled = pendingFileTabReads[id] {
      await scheduled.value
    } else {
      await readFileTab(id)
    }
    // The tab or its bar may have gone meanwhile.
    return refusalToReachFileTabOnScreen(id) ?? refusalToFind(action, in: id)
  }

  /// A hidden tab lets its rows go, and the arrows and find read the view's.
  private func refusalToReachFileTabOnScreen(_ id: WorkspaceTab.ID) -> ControlRefusal? {
    if let refusal = refusalToReachFileTab(id) { return refusal }
    guard platform.isWorkspaceWindowVisible else { return .noWindow }
    return isFileTabShown(id) ? nil : .tabNotShown(id: id)
  }
}
