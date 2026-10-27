import MultishellCore

extension AppModel {
  /// Topmost first: an alert stands over the dialog or sheet it came from.
  var presentations: [PresentationEntry] {
    var up: [PresentationEntry] = []
    if let alert = presentedError {
      up.append(PresentationEntry(.alert, title: alert.title, message: alert.message))
    }
    if pendingClose != nil { up.append(PresentationEntry(.closeConfirmation)) }
    if pendingWorktreeRemoval != nil { up.append(PresentationEntry(.worktreeRemoval)) }
    if pendingProjectRemoval != nil { up.append(PresentationEntry(.projectRemoval)) }
    if pendingSharedSettingsTrust != nil { up.append(PresentationEntry(.sharedSettingsTrust)) }
    if pendingBranchPublish != nil { up.append(PresentationEntry(.branchPublish)) }
    if newWorktreeRequest != nil { up.append(PresentationEntry(.newWorktree)) }
    if quickSwitcher != nil { up.append(PresentationEntry(.quickSwitcher)) }
    if renamingTabID != nil { up.append(PresentationEntry(.tabRename)) }
    if renamingWorktreeID != nil { up.append(PresentationEntry(.worktreeRename)) }
    return up
  }

  /// The topmost's Cancel, or its Escape for a name field; answers what went.
  func replyToDismissPresentation() -> ControlReply {
    guard let top = presentations.first else { return .refused(.nothingPresented) }
    dismiss(top.kind)
    return .json(top)
  }

  private func dismiss(_ kind: PresentationEntry.Kind) {
    switch kind {
    case .alert:
      if let alert = presentedError { answerPresentedError(alert, retrying: false) }

    case .closeConfirmation:
      if let close = pendingClose { answerClose(close, confirmed: false) }

    case .worktreeRemoval:
      if let removal = pendingWorktreeRemoval { answerWorktreeRemoval(removal, choice: nil) }

    case .projectRemoval:
      if let removal = pendingProjectRemoval { answerProjectRemoval(removal, confirmed: false) }

    case .sharedSettingsTrust: decideSharedSettingsTrustLater()

    case .branchPublish:
      if let publish = pendingBranchPublish { answerBranchPublish(publish, publishes: false) }

    // Closed, not cancelled: a create running may be a request's, not the sheet's.
    case .newWorktree: newWorktreeRequest = nil

    case .quickSwitcher: closeQuickSwitcher()

    case .tabRename: cancelRenamingTab()
    case .worktreeRename: cancelRenamingWorktree()
    }
  }
}
