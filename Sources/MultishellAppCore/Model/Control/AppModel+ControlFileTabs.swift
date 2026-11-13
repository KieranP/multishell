import Foundation
import MultishellCore

extension AppModel {
  /// A click on the file's Files panel row, by the same rule; in a worktree out
  /// of view it opens without switching, as `tabs open` does.
  func replyToOpenFileTab(_ path: String, in id: String) async -> ControlReply {
    guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    let opened = await openFileAsTab(path, in: worktree.id, as: .request)
    // Opened or not, the check built a listing the panel may not show.
    forgetUnreadFileListings()
    guard let tab = opened else {
      let isGone = workspace.worktree(worktree.id) == nil
      return .refused(isGone ? .noWorktree(id: id) : .fileNotOpenable(path: path))
    }
    return .json(["tab": tab.id])
  }

  /// The bar's arrow. Queued for the tab's view, which the arrow needs on screen.
  func replyToStepToChange(_ direction: CycleDirection, in id: FileTab.ID) async -> ControlReply {
    let refusal = await refusalToActOnRowsOnceRead(of: id) {
      refusalToReachFileTab(id) ?? refusalToShowReachedFileTab(id)
    }
    if let refusal { return .refused(refusal) }
    // The bar draws arrows only over rows with line changes.
    if case .text(let rows) = fileTabReadings[id]?.content, !rows.hasLineChanges {
      return .refused(.noChangeThatWay(id: id))
    }
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
    if action == .close {
      if let refusal = refusalToReachFileTab(id) { return .refused(refusal) }
      return endFind(in: id) ? replyToDescribeTab(id) : .refused(.noFindBar(id: id))
    }
    let refusal = await refusalToActOnRowsOnceRead(of: id) {
      refusalToReachFileTab(id) ?? refusalToFind(action, in: id) ?? refusalToShowReachedFileTab(id)
    }
    if let refusal { return .refused(refusal) }
    if case .open(let text) = action {
      openFind(on: text, in: id)
    } else {
      action == .next ? findNext(in: id) : findPrevious(in: id)
    }
    return replyToDescribeTab(id)
  }

  /// Waits on the scheduled read; rows not in hand are refused for the helper to ask
  /// again, and a notice or image has none (agents/command-line.md, a file tab's arrows and find).
  func refusalToActOnRowsOnceRead(
    of id: FileTab.ID,
    _ refusalNow: () -> ControlRefusal?,
  ) async -> ControlRefusal? {
    if let refusal = refusalNow() { return refusal }
    let holdsNothing = !holdsContent(id)
    // A notice or an image may yet turn to rows, so its scheduled read is waited on too.
    let awaitsRead = holdsNothing || (drawsNoRows(id) && pendingFileTabReads[id] != nil)
    if awaitsRead, !fileTabReadLog.isReading(id) {
      if holdsNothing, coordinator == nil { return .gitNotFound }
      if let scheduled = pendingFileTabReads[id] {
        await scheduled.value
      } else {
        await readFileTab(id)
      }
      // The tab or its bar may have gone meanwhile.
      if let refusal = refusalNow() { return refusal }
    }
    guard holdsContent(id) else { return .fileTabNotRead(id: id) }
    guard drawsNoRows(id) else { return nil }
    if fileTabReadLog.isReading(id) { return .fileTabNotRead(id: id) }
    return holdsImage(id) ? .fileTabShowsImage(id: id) : .fileTabShowsNotice(id: id)
  }

  /// A hidden tab lets its rows go, and the arrows and find read the view's,
  /// which a worktree's operation draws in place of its groups.
  private func refusalToShowReachedFileTab(_ id: WorkspaceTab.ID) -> ControlRefusal? {
    if let refusal = refusalToReadInWorkspaceWindow { return refusal }
    guard isFileTabShown(id) else { return .tabNotShown(id: id) }
    if case .operation(let worktree, _) = detailContent {
      return .worktreeNotReady(id: ControlID.worktree(worktree.id))
    }
    return nil
  }
}
