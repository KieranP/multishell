import Foundation
import MultishellCore

/// `multishell review`: Review's list, a composer's Add, Send and Clear sent.
extension AppModel {
  func replyToListReviewComments(in id: String?) async -> ControlReply {
    await replyingInWorktree(id) { worktree in reviewListing(of: worktree) }
  }

  /// Quoted from the file's open tab, as a comment written there is; never
  /// the All changes tab (owner's pick).
  func replyToAddReviewComment(_ order: ReviewCommentOrder) async -> ControlReply {
    await replyingInWorktree(order.worktreeID) { worktree in
      await replyToAdd(order, in: worktree)
    }
  }

  /// Unchanged lines are the file on disk's, as a comment written in the tab is.
  private func replyToAdd(_ order: ReviewCommentOrder, in worktree: Worktree) async -> ControlReply
  {
    // The request's own words first, as command-line.md has every request named.
    guard let text = order.text.trimmedOfAllWhitespaceOrNil else {
      return .refused(.invalidValue(key: "text", value: order.text))
    }
    // A link's tab is keyed by its target, as a click on the link opens it.
    let path = WorktreeLinkTarget.path(of: order.path, in: worktree.path) ?? order.path
    let tabID: ReviewTabID
    switch await readReviewTab(showing: path, asked: order.path, in: worktree) {
    case .success(let id): tabID = id
    case .failure(let refusal): return .refused(refusal)
    }
    guard workspace.worktree(worktree.id) != nil else {
      return .refused(.noWorktree(id: ControlID.worktree(worktree.id)))
    }
    let quote = reviewQuote(of: order.lines, on: order.side, ofFile: path, in: tabID)
    // Lines start at 1, and a socket line can name any range: `count` traps past `Int.max`.
    guard order.lines.lowerBound >= 1, quote.count == order.lines.count else {
      return .refused(.noReviewLines(path: order.path))
    }
    guard order.side == .onDisk || holdsRemovedLines(order.lines, ofFile: path, in: tabID) else {
      return .refused(.noRemovedLines(path: order.path))
    }
    let comment = ReviewComment(
      path: path,
      side: order.side,
      scope: fileTabScope(in: worktree.id),
      lines: order.lines,
      quote: quote,
      text: text,
    )
    guard addReviewComment(comment, in: worktree.id) else {
      return .refused(.invalidValue(key: "text", value: order.text))
    }
    return reviewListing(of: worktree)
  }

  /// The shown file tab whose rows the quote comes from, read now, so an edit made a
  /// moment ago, noticed or not, is what is quoted; `asked` is the path as named.
  private func readReviewTab(
    showing path: String,
    asked: String,
    in worktree: Worktree,
  ) async -> Result<ReviewTabID, ControlRefusal> {
    guard let tab = workspace.fileTab(showing: path, in: worktree.id) else {
      return .failure(.noReviewTab(path: asked))
    }
    let refusalToQuote = {
      self.refusalToReadInWorkspaceWindow
        ?? (self.isTabShown(tab.id) ? nil : .tabNotShown(id: tab.id))
    }
    if let refusal = refusalToQuote() { return .failure(refusal) }
    if fileTabReadLog.isReading(tab.id) { return .failure(.fileTabNotRead(id: tab.id)) }
    await readFileTab(tab.id)
    // A notice or image is refused as `tabs step` refuses it.
    if let unread = await refusalToActOnRowsOnceRead(of: tab.id, refusalToQuote) {
      return .failure(unread)
    }
    return .success(tab.id)
  }

  func replyToSendReview(in id: String?, to sessionID: UUID?) async -> ControlReply {
    await replyingInWorktree(id) { worktree in replyToSend(of: worktree, to: sessionID) }
  }

  private func replyToSend(of worktree: Worktree, to sessionID: UUID?) -> ControlReply {
    let worktreeControlID = ControlID.worktree(worktree.id)
    guard reviewComments(in: worktree.id).contains(where: \.isPending) else {
      return .refused(.nothingToSend(id: worktreeControlID))
    }
    guard let recipient = handoffRecipient(named: sessionID, in: worktree.id) else {
      return .refused(.noRecipient(id: worktreeControlID))
    }
    // As `panes paste`: the pane keeps whatever had the keyboard.
    guard sendReview(of: worktree.id, to: recipient.id, takingFocus: false) else {
      return .refused(.paneNotLive(id: recipient.id))
    }
    return reviewListing(of: worktree)
  }

  func replyToClearReviewComments(in id: String?, sentOnly: Bool) async -> ControlReply {
    await replyingInWorktree(id) { worktree in
      if sentOnly {
        clearSentReviewComments(in: worktree.id)
      } else {
        removeReviewComments(Set(reviewComments(in: worktree.id).map(\.id)), in: worktree.id)
      }
      return reviewListing(of: worktree)
    }
  }

  private func holdsRemovedLines(
    _ lines: ClosedRange<Int>,
    ofFile path: String,
    in tabID: ReviewTabID,
  ) -> Bool {
    (reviewRows(ofFile: path, in: tabID) ?? []).contains { line in
      line.kind == .removed && line.number(on: .committed).map(lines.contains) == true
    }
  }

  private func reviewListing(of worktree: Worktree) -> ControlReply {
    .json(
      ReviewListing(
        worktree: ControlID.worktree(worktree.id),
        comments: reviewComments(in: worktree.id),
      )
    )
  }
}
