import MultishellCore

extension AppModel {
  /// The cards drawn for `lines`, a tab's Unified rows or the `side` column's. A
  /// committed-side card shows only under its scope, `HEAD` and the base differing.
  public func reviewCardPlacements(
    of tab: FileTab,
    in lines: [DiffLine],
    side: DiffSide? = nil,
  ) -> [ReviewCardPlacement] {
    let sources = reviewCardSources(of: tab.id, in: tab.worktreeID, side: side)
    return ReviewCardPlacement.placements(
      of: sources.comments(onFile: tab.path),
      selected: selectedReviewComments[tab.worktreeID],
      composer: sources.composer(onFile: tab.path),
      in: lines,
    )
  }

  /// The composer and comments a tab's cards show on `side`, `nil` for both;
  /// those that do not apply under the worktree's scope are left out.
  func reviewCardSources(
    of tabID: ReviewTabID,
    in worktreeID: Worktree.ID,
    side: DiffSide?,
  ) -> ReviewCardSources {
    let scope = fileTabScope(in: worktreeID)
    let composer = reviewComposers[tabID].flatMap { composer in
      (side == nil || composer.side == side) && composer.appliesUnder(scope) ? composer : nil
    }
    let shown = reviewComments(in: worktreeID).filter { comment in
      comment.id != composer?.editing && (side == nil || comment.side == side)
        && comment.appliesUnder(scope)
    }
    return ReviewCardSources(
      composer: composer,
      commentsByPath: Dictionary(grouping: shown, by: \.path),
    )
  }

  /// The view's, as it updates: the card to scroll to, once the tab has rows to
  /// place it by. Taken then even where it is not drawn, so it never fires later.
  public func takeReviewCardReveal(_ id: ReviewTabID) -> ReviewCardPlacement.CardID? {
    // A removal of nothing still redraws every file tab, each update asking here.
    guard let card = reviewCardRevealRequests[id], holdsReviewRows(id, for: card) else {
      return nil
    }
    return reviewCardRevealRequests.removeValue(forKey: id)
  }

  /// Rows to place a card by: a file tab's text, or in the All changes tab
  /// the read of the comment's file, which waits unread away from the screen.
  private func holdsReviewRows(_ id: ReviewTabID, for card: ReviewCardPlacement.CardID) -> Bool {
    switch workspace.workspaceTab(id) {
    case .allChanges(let tab):
      guard let reading = allChangesReadings[id] else { return false }
      guard case .comment(let commentID) = card,
        let path = reviewComments(in: tab.worktreeID).first(where: { $0.id == commentID })?.path
      else { return true }
      return !reading.isUnread(path)

    case .file:
      guard case .text = fileTabReadings[id]?.content else { return false }
      return true

    case .terminal, nil: return false
    }
  }
}
