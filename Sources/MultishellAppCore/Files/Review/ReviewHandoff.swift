import Foundation
import MultishellCore

/// What Send writes for the agent: every pending comment of a worktree as one
/// note; see Docs/design/files/review-comments.md.
enum ReviewHandoff {
  private static var maxNameLength: Int { 200 }

  static var introduction: String { t("review.handoff-introduction") }

  static func entries(of comments: [ReviewComment]) -> [AgentHandoffEntry] {
    comments.inReviewOrder.map(entry(of:))
  }

  /// Named for the worktree in the characters every file name takes, cut to a
  /// length every disk takes.
  static func fileName(forWorktreeNamed name: String) -> String {
    "review-\(name.portableName(maxLength: maxNameLength)).md"
  }

  private static func entry(of comment: ReviewComment) -> AgentHandoffEntry {
    let lines =
      comment.lines.count == 1
      ? "\(comment.lines.lowerBound)"
      : "\(comment.lines.lowerBound)-\(comment.lines.upperBound)"
    // HEAD and the base branch number removed lines differently, so the file says whose.
    let place: String =
      switch (comment.side, comment.scope) {
      case (.onDisk, _): lines
      case (.committed, .modified): t("review.handoff-removed-lines-head", lines)
      case (.committed, .branch): t("review.handoff-removed-lines-base", lines)
      }
    return AgentHandoffEntry(
      heading: "\(comment.path):\(place)",
      caveat: comment.hasChangedLines ? t("review.handoff-lines-changed") : nil,
      quote: comment.quote,
      text: comment.text,
    )
  }
}
