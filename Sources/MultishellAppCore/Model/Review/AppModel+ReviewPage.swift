import MultishellCore

extension AppModel {
  /// Review's glyph carries a dot while a comment waits to be sent and the page
  /// is not the one shown: files/panel.md rules out a count on the switch.
  public var showsReviewDot: Bool {
    guard shownFilesPanelMode != .review, let worktree = filesPanelWorktree else { return false }
    return reviewComments(in: worktree.id).contains(where: \.isPending)
  }

  public func reviewPage(of worktreeID: Worktree.ID) -> ReviewPage {
    ReviewPage(
      comments: reviewComments(in: worktreeID),
      shownScope: fileTabScope(in: worktreeID),
      selected: selectedReviewComments[worktreeID],
    )
  }

  /// "No comments in kp/settings-scope", and how to start one.
  public func reviewEmptyText(of worktree: Worktree) -> PanelPageEmptyText {
    PanelPageEmptyText(
      title: t("review.empty", workspace.displayName(of: worktree)),
      detail: t("review.empty-hint"),
    )
  }

  public func reviewFooter(of worktree: Worktree) -> ReviewFooter {
    let comments = reviewComments(in: worktree.id)
    let hasPending = comments.contains(where: \.isPending)
    // Said only while what was sent is still listed: Clear sent or a last Dismiss ends it.
    if !hasPending, !comments.isEmpty, let receipt = reviewSendReceipts[worktree.id] {
      return .sent(receipt)
    }
    let recipients = reviewRecipients(in: worktree.id)
    guard let picked = reviewRecipient(from: recipients, in: worktree.id) else {
      return .noRecipient(t("review.no-agent", workspace.displayName(of: worktree)))
    }
    return .ready(picked: picked, recipients: recipients, canSend: hasPending)
  }

  /// A click on a comment's row: the All changes tab where a group shows it,
  /// else its file's tab, opened where it is not, with the card scrolled into
  /// view and outlined.
  public func selectReviewComment(_ id: ReviewComment.ID, in worktreeID: Worktree.ID) async {
    guard let comment = reviewComments(in: worktreeID).first(where: { $0.id == id }) else {
      return
    }
    setIfChanged(\.selectedReviewComments[worktreeID], id)
    if let allChanges = workspace.allChangesTab(in: worktreeID),
      workspace.group(allChanges.groupID)?.shownTabID == allChanges.id
    {
      activateTab(allChanges.id)
      // A collapsed file places no card to scroll to.
      if allChangesCollapsedFiles[allChanges.id]?.contains(comment.path) == true {
        allChangesCollapsedFiles[allChanges.id]?.remove(comment.path)
      }
      reviewCardRevealRequests[allChanges.id] = .comment(id)
      return
    }
    let tab: FileTab?
    if let open = workspace.fileTab(showing: comment.path, in: worktreeID) {
      activateTab(open.id)
      tab = open
    } else {
      tab = await openFileAsTab(comment.path, in: worktreeID, as: .click)
    }
    guard let tab, selectedReviewComments[worktreeID] == id else { return }
    reviewCardRevealRequests[tab.id] = .comment(id)
  }
}
