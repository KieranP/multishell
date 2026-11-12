import Foundation
import MultishellCore

/// What `multishell review` prints: a worktree's comments in the order Send
/// writes them.
struct ReviewListing: Encodable, Equatable {
  struct Comment: Encodable, Equatable {
    let id: UUID
    let path: String
    /// On lines the file no longer has, numbered by the committed side.
    let isOnRemovedLines: Bool
    let firstLine: Int
    let lastLine: Int
    /// `pending`, `sent` or `outdated`.
    let state: String
    /// Who a sent or outdated comment went to.
    let agent: String?
    /// Its lines no longer read as written; a sent comment's did not when sent.
    let hasChangedLines: Bool
    let text: String
  }

  /// Its worktree's `ControlID`.
  let worktree: String
  let comments: [Comment]

  init(worktree: String, comments: [ReviewComment]) {
    self.worktree = worktree
    self.comments = comments.inReviewOrder.map { comment in
      let (state, agent): (String, String?) =
        switch comment.state {
        case .pending: ("pending", nil)
        case .sent(let agentName, _): ("sent", agentName)
        case .outdated(let agentName, _): ("outdated", agentName)
        }
      return Comment(
        id: comment.id,
        path: comment.path,
        isOnRemovedLines: comment.side == .committed,
        firstLine: comment.lines.lowerBound,
        lastLine: comment.lines.upperBound,
        state: state,
        agent: agent,
        hasChangedLines: comment.hasChangedLines,
        text: comment.text,
      )
    }
  }
}
