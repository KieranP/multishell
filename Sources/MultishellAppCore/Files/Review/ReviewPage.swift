import MultishellCore

/// What the Files panel's Review page draws for one worktree, every decision
/// made here; see Docs/design/files/review-comments.md.
public struct ReviewPage: Equatable, Sendable {
  /// "2 to send", `nil` with none pending.
  public let pendingText: String?
  public let showsClearSent: Bool
  /// In path order.
  public let groups: [ReviewFileGroup]

  public var isEmpty: Bool { groups.isEmpty }

  init(
    comments: [ReviewComment],
    shownScope: ChangeScope,
    selected: ReviewComment.ID?,
  ) {
    let pendingCount = comments.count(where: \.isPending)
    pendingText = pendingCount > 0 ? t("count.to-send", pendingCount) : nil
    showsClearSent = comments.contains { !$0.isPending }
    let byPath = Dictionary(grouping: comments, by: \.path)
    groups = byPath.keys.sorted().map { path in
      let fileComments = (byPath[path] ?? []).inReviewOrder
      let pending = fileComments.count(where: \.isPending)
      return ReviewFileGroup(
        path: path,
        fileName: String(path.slashSeparatedParts.last ?? Substring(path)),
        countText: pending > 0
          ? t("count.to-send", pending) : t("count.comments", fileComments.count),
        rows: fileComments.map { comment in
          ReviewRow(
            id: comment.id,
            lineLabel: comment.lineLabel,
            scopeNote: Self.scopeNote(of: comment, shownScope: shownScope),
            chip: ReviewChip(comment),
            text: comment.text,
            isSelected: comment.id == selected,
          )
        },
      )
    }
  }

  private static func scopeNote(of comment: ReviewComment, shownScope: ChangeScope) -> String? {
    guard comment.side == .committed, comment.scope != shownScope else { return nil }
    switch comment.scope {
    case .branch: return t("review.scope-branch")
    case .modified: return t("review.scope-modified")
    }
  }
}
