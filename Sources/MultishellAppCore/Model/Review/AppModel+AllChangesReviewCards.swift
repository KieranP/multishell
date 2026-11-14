import MultishellCore

/// Review cards in the All changes tab: each file's placed against that file's
/// own rows, then moved to the document's, so two files' line numbers never meet.
extension AppModel {
  /// A comment on an unchanged line keeps this many either side open inside a fold.
  private static var reviewLinesHeldAround: Int { 2 }

  /// A collapsed file's cards are left out; a committed-side card shows only
  /// under its scope, as in a file tab. `side` is a split column's.
  public func reviewCardPlacements(
    of tab: AllChangesTab,
    in document: AllChangesDocument,
    side: DiffSide? = nil,
  ) -> [ReviewCardPlacement] {
    let scope = fileTabScope(in: tab.worktreeID)
    let composer = reviewComposers[tab.id].flatMap { composer in
      (side == nil || composer.side == side) && composer.appliesUnder(scope) ? composer : nil
    }
    let commentsByPath = Dictionary(
      grouping: reviewComments(in: tab.worktreeID).filter { comment in
        comment.id != composer?.editing && (side == nil || comment.side == side)
          && comment.appliesUnder(scope)
      },
      by: \.path,
    )
    let selected = selectedReviewComments[tab.worktreeID]
    return document.sections.flatMap { section -> [ReviewCardPlacement] in
      let comments = commentsByPath[section.path] ?? []
      let fileComposer = composer?.path == section.path ? composer : nil
      guard !comments.isEmpty || fileComposer != nil, let fileText = section.sideText(on: side)
      else {
        return []
      }
      return ReviewCardPlacement.placements(
        of: comments,
        selected: selected,
        composer: fileComposer,
        in: fileText.lines,
      )
      // A file shown whole has no rows in either column; its own view places them.
      .compactMap { placement in
        guard let first = section.documentRow(ofFileRow: placement.rows.lowerBound),
          let last = section.documentRow(ofFileRow: placement.rows.upperBound)
        else { return nil }
        return placement.moved(to: first...last)
      }
    }
  }

  /// The cards of one file the All changes tab shows whole across Split's
  /// columns, on that file's own Unified rows.
  public func reviewCardPlacements(
    of tab: AllChangesTab,
    onWholeFile path: String,
    in lines: [DiffLine],
  ) -> [ReviewCardPlacement] {
    let scope = fileTabScope(in: tab.worktreeID)
    let composer = reviewComposers[tab.id].flatMap { composer in
      composer.path == path && composer.appliesUnder(scope) ? composer : nil
    }
    let comments = reviewComments(in: tab.worktreeID).filter { comment in
      comment.path == path && comment.id != composer?.editing && comment.appliesUnder(scope)
    }
    return ReviewCardPlacement.placements(
      of: comments,
      selected: selectedReviewComments[tab.worktreeID],
      composer: composer,
      in: lines,
    )
  }

  /// Each file's comments and composer, two lines either side, kept out of its
  /// folds so their cards have rows to sit under.
  func allChangesReviewLines(of tab: AllChangesTab) -> [String: [AllChangesLineSpan]] {
    let scope = fileTabScope(in: tab.worktreeID)
    let shown =
      reviewComments(in: tab.worktreeID).filter { $0.appliesUnder(scope) }
      .map { ($0.path, $0.side, $0.lines) }
      + (reviewComposers[tab.id].map { [($0.path, $0.side, $0.lines)] } ?? [])
    return Dictionary(
      grouping: shown.map { path, side, lines in
        (
          path,
          AllChangesLineSpan(
            side: side,
            lines: max(
              1,
              lines.lowerBound - Self.reviewLinesHeldAround,
            )...(lines.upperBound + Self.reviewLinesHeldAround),
          ),
        )
      },
      by: \.0,
    )
    .mapValues { $0.map(\.1) }
  }
}
