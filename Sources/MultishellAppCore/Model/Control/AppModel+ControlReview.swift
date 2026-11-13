import Foundation
import MultishellCore

/// `multishell review`: Review's list, a composer's Add, Send and Clear sent.
extension AppModel {
  func replyToListReviewComments(in id: String?) async -> ControlReply {
    await replyingInReviewedWorktree(id) { worktree in reviewListing(of: worktree) }
  }

  /// Quoted from the file's open tab, as a comment written there is.
  func replyToAddReviewComment(_ order: ReviewCommentOrder) async -> ControlReply {
    await replyingInReviewedWorktree(order.worktreeID) { worktree in
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
    guard let tab = workspace.fileTab(showing: path, in: worktree.id) else {
      return .refused(.noReviewTab(path: order.path))
    }
    let refusalToQuote = {
      self.refusalToReadInWorkspaceWindow
        ?? (self.isFileTabShown(tab.id) ? nil : .tabNotShown(id: tab.id))
    }
    if let refusal = refusalToQuote() { return .refused(refusal) }
    // Read now, so an edit made a moment ago, noticed or not, is what is quoted; the
    // checks below then judge that reading, a notice or image refused as `tabs step` is.
    if fileTabReadLog.isReading(tab.id) { return .refused(.fileTabNotRead(id: tab.id)) }
    await readFileTab(tab.id)
    if let unread = await refusalToActOnRowsOnceRead(of: tab.id, refusalToQuote) {
      return .refused(unread)
    }
    guard workspace.worktree(worktree.id) != nil else {
      return .refused(.noWorktree(id: ControlID.worktree(worktree.id)))
    }
    let quote = reviewQuote(of: order.lines, on: order.side, in: tab.id)
    // Lines start at 1, and a socket line can name any range: `count` traps past `Int.max`.
    guard order.lines.lowerBound >= 1, quote.count == order.lines.count else {
      return .refused(.noReviewLines(path: order.path))
    }
    guard order.side == .onDisk || holdsRemovedLines(order.lines, in: tab.id) else {
      return .refused(.noRemovedLines(path: order.path))
    }
    let comment = ReviewComment(
      path: tab.path,
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

  func replyToSendReview(in id: String?, to sessionID: UUID?) async -> ControlReply {
    await replyingInReviewedWorktree(id) { worktree in replyToSend(of: worktree, to: sessionID) }
  }

  private func replyToSend(of worktree: Worktree, to sessionID: UUID?) -> ControlReply {
    let worktreeControlID = ControlID.worktree(worktree.id)
    guard reviewComments(in: worktree.id).contains(where: \.isPending) else {
      return .refused(.nothingToSend(id: worktreeControlID))
    }
    let recipient =
      if let sessionID {
        reviewRecipients(in: worktree.id).first { $0.id == sessionID }
      } else {
        reviewRecipient(in: worktree.id)
      }
    guard let recipient else { return .refused(.noReviewRecipient(id: worktreeControlID)) }
    // As `panes paste`: the pane keeps whatever had the keyboard.
    guard sendReview(of: worktree.id, to: recipient.id, takingFocus: false) else {
      return .refused(.paneNotLive(id: recipient.id))
    }
    return reviewListing(of: worktree)
  }

  func replyToClearReviewComments(in id: String?, sentOnly: Bool) async -> ControlReply {
    await replyingInReviewedWorktree(id) { worktree in
      if sentOnly {
        clearSentReviewComments(in: worktree.id)
      } else {
        removeReviewComments(Set(reviewComments(in: worktree.id).map(\.id)), in: worktree.id)
      }
      return reviewListing(of: worktree)
    }
  }

  /// `reply` in the worktree named, else the one in view; refused where there is none.
  private func replyingInReviewedWorktree(
    _ id: String?,
    _ reply: (Worktree) async -> ControlReply,
  ) async -> ControlReply {
    let named = id.map { worktree(withControlID: $0) } ?? worktreeInView
    guard let worktree = named else {
      return .refused(id.map { .noWorktree(id: $0) } ?? .nothingInView)
    }
    return await reply(worktree)
  }

  private func holdsRemovedLines(_ lines: ClosedRange<Int>, in tabID: FileTab.ID) -> Bool {
    guard case .text(let rows) = fileTabReadings[tabID]?.content else { return false }
    return rows.lines.contains { line in
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
