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
      (side == nil || composer.side == side) && composer.appliesUnder(scope) ? composer : nil
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
  public func takeReviewCardReveal(_ id: FileTab.ID) -> ReviewCardPlacement.CardID? {
    // A removal of nothing still redraws every file tab, each update asking here.
    guard reviewCardRevealRequests[id] != nil, case .text = fileTabReadings[id]?.content
    else { return nil }
    return reviewCardRevealRequests.removeValue(forKey: id)
  }
}
