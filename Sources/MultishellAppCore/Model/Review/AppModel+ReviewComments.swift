import Foundation
import MultishellCore

extension AppModel {
  func reviewComments(in worktreeID: Worktree.ID) -> [ReviewComment] {
    reviewComments[worktreeID] ?? []
  }

  /// Refused for a worktree no longer listed or a comment with no text.
  @discardableResult
  func addReviewComment(_ comment: ReviewComment, in worktreeID: Worktree.ID) -> Bool {
    guard workspace.worktree(worktreeID) != nil, comment.text.trimmedOfAllWhitespaceOrNil != nil
    else { return false }
    setReviewComments(reviewComments(in: worktreeID) + [comment], of: worktreeID)
    setIfChanged(\.reviewSendReceipts[worktreeID], nil)
    return true
  }

  /// Only a pending comment's text changes, a sent one being what the agent read.
  func editReviewComment(_ id: ReviewComment.ID, in worktreeID: Worktree.ID, text: String) {
    guard text.trimmedOfAllWhitespaceOrNil != nil else { return }
    updateReviewComments(in: worktreeID) { comment in
      guard comment.id == id else { return }
      comment.edit(text: text)
    }
  }

  /// The speech-bubble count on a file tab's title.
  public func pendingReviewCommentCount(of tab: FileTab) -> Int {
    reviewComments[tab.worktreeID]?.count { $0.path == tab.path && $0.isPending } ?? 0
  }

  /// Every file's in the worktree, which the All changes tab shows together.
  public func pendingReviewCommentCount(of tab: AllChangesTab) -> Int {
    reviewComments[tab.worktreeID]?.count(where: \.isPending) ?? 0
  }

  /// Every file's count at once, for its row in Files and Changes, so a list's rows
  /// take theirs from one pass.
  public func pendingReviewCommentCounts(in worktreeID: Worktree.ID) -> [String: Int] {
    reviewComments(in: worktreeID).filter(\.isPending).reduce(into: [:]) { counts, comment in
      counts[comment.path, default: 0] += 1
    }
  }

  /// A sent or outdated comment's Dismiss, and a pending one's Delete.
  public func removeReviewComment(_ id: ReviewComment.ID, in tabID: ReviewTabID) {
    guard let worktreeID = reviewWorktree(of: tabID) else { return }
    removeReviewComments([id], in: worktreeID)
  }

  public func removeReviewComments(_ ids: Set<ReviewComment.ID>, in worktreeID: Worktree.ID) {
    keepReviewComments(in: worktreeID) { !ids.contains($0.id) }
  }

  /// Every comment no longer pending, Review's Clear sent.
  public func clearSentReviewComments(in worktreeID: Worktree.ID) {
    keepReviewComments(in: worktreeID, where: \.isPending)
  }

  func markReviewCommentsSent(
    _ ids: Set<ReviewComment.ID>,
    in worktreeID: Worktree.ID,
    to agentName: String,
    at date: Date,
  ) {
    updateReviewComments(in: worktreeID) { comment in
      guard ids.contains(comment.id) else { return }
      comment.markSent(to: agentName, at: date)
    }
  }

  /// A removed worktree's review goes with it: comments, file, picks and receipts.
  /// Its file stays known, so a quit before the removal lands removes it again.
  func forgetReviewState(of gone: Set<Worktree.ID>) {
    for id in gone where reviewFiles[id] != nil {
      setReviewComments([], of: id)
    }
    for id in gone {
      worktreesWithReviewFilesRead.remove(id)
      // A write of nil to a key never set still redraws every file tab.
      setIfChanged(\.reviewRecipientPicks[id], nil)
      setIfChanged(\.reviewSendReceipts[id], nil)
      setIfChanged(\.focusedSessionHistory[id], nil)
      setIfChanged(\.selectedReviewComments[id], nil)
    }
  }

  /// Written only where one goes, so a Clear with nothing to clear touches no file.
  private func keepReviewComments(
    in worktreeID: Worktree.ID,
    where isKept: (ReviewComment) -> Bool,
  ) {
    let comments = reviewComments(in: worktreeID)
    let kept = comments.filter(isKept)
    guard kept.count != comments.count else { return }
    setReviewComments(kept, of: worktreeID)
  }

  private func updateReviewComments(
    in worktreeID: Worktree.ID,
    _ change: (inout ReviewComment) -> Void,
  ) {
    var comments = reviewComments(in: worktreeID)
    for index in comments.indices { change(&comments[index]) }
    guard comments != reviewComments(in: worktreeID) else { return }
    setReviewComments(comments, of: worktreeID)
  }
}
