import MultishellCore

extension AppModel {
  /// The cards drawn for `lines`, a tab's Unified rows or the `side` column's. A
  /// committed-side card shows only under its scope, `HEAD` and the base differing.
  public func reviewCardPlacements(
    of tab: FileTab,
    in lines: [DiffLine],
    side: DiffSide? = nil,
  ) -> [ReviewCardPlacement] {
    let scope = fileTabScope(in: tab.worktreeID)
    let composer = reviewComposers[tab.id].flatMap { composer in
      composer.path == tab.path && (side == nil || composer.side == side)
        && composer.appliesUnder(scope) ? composer : nil
    }
    let comments = reviewComments(in: tab.worktreeID).filter { comment in
      comment.path == tab.path && comment.id != composer?.editing
        && (side == nil || comment.side == side)
        && comment.appliesUnder(scope)
    }
    return ReviewCardPlacement.placements(
      of: comments,
      selected: selectedReviewComments[tab.worktreeID],
      composer: composer,
      in: lines,
    )
  }

  /// The view's, as it updates: the card to scroll to, once the tab has rows to
  /// place it by. Taken then even where it is not drawn, so it never fires later.
  public func takeReviewCardReveal(_ id: ReviewTabID) -> ReviewCardPlacement.CardID? {
    // A removal of nothing still redraws every file tab, each update asking here.
    guard reviewCardRevealRequests[id] != nil, holdsReviewRows(id) else { return nil }
    return reviewCardRevealRequests.removeValue(forKey: id)
  }

  /// Rows to place a card by: a file tab's text, or the All changes tab's read.
  private func holdsReviewRows(_ id: ReviewTabID) -> Bool {
    switch workspace.workspaceTab(id) {
    case .allChanges: allChangesReadings[id] != nil
    case .file: if case .text = fileTabReadings[id]?.content { true } else { false }
    case .terminal, nil: false
    }
  }
}
