import MultishellCore

/// Review cards in the All changes tab: each file's placed against that file's
/// own rows, then moved to the document's, so two files' line numbers never meet.
extension AppModel {
  /// A comment on an unchanged line keeps this many either side open inside a fold.
  private static var reviewLinesHeldAround: Int { 2 }

  /// Where a card Review picked sits: its file and its first line's row in that
  /// file's view, either side in Split; `nil` where no card stands for it.
  public func reviewCardRow(
    _ card: ReviewCardPlacement.CardID,
    of tab: AllChangesTab,
    in document: AllChangesDocument,
  ) -> AllChangesFileRow? {
    guard let path = reviewCardPath(card, in: tab), let section = document.section(at: path)
    else { return nil }
    let sides: [DiffSide?] = document.split == nil ? [nil] : [.onDisk, .committed]
    let placement = sides.lazy.compactMap { side in
      self.reviewCardPlacements(of: tab, in: document, section: section, side: side)
        .first { $0.stands(for: card) }
    }.first
    return placement.map { AllChangesFileRow(section: section, row: $0.rows.lowerBound) }
  }

  /// The file a card is on: its comment's, or the composer's.
  private func reviewCardPath(_ card: ReviewCardPlacement.CardID, in tab: AllChangesTab) -> String?
  {
    switch card {
    case .comment(let id): reviewComments(in: tab.worktreeID).first { $0.id == id }?.path
    case .composer: reviewComposers[tab.id]?.path
    }
  }

  /// One file's cards on its own shown rows, for its view in the per-file list:
  /// a collapsed file's are left out, and a committed-side card shows only under
  /// its scope, as in a file tab. `side` is a split column's.
  public func reviewCardPlacements(
    of tab: AllChangesTab,
    in document: AllChangesDocument,
    section index: Int,
    side: DiffSide? = nil,
  ) -> [ReviewCardPlacement] {
    let section = document.sections[index]
    let sources = reviewCardSources(of: tab.id, in: tab.worktreeID, side: side)
    let comments = sources.comments(onFile: section.path)
    let fileComposer = sources.composer(onFile: section.path)
    guard !comments.isEmpty || fileComposer != nil, let fileText = section.sideText(on: side)
    else { return [] }
    return ReviewCardPlacement.placements(
      of: comments,
      selected: selectedReviewComments[tab.worktreeID],
      composer: fileComposer,
      in: fileText.lines,
    )
    // A card on lines no shown row holds, folded away, places none.
    .compactMap { placement in
      guard let first = section.documentRow(ofFileRow: placement.rows.lowerBound),
        let last = section.documentRow(ofFileRow: placement.rows.upperBound)
      else { return nil }
      return placement.moved(
        to: (first - section.rows.lowerBound)...(last - section.rows.lowerBound)
      )
    }
  }

  /// The cards of one file the All changes tab shows whole across Split's
  /// columns, on that file's own Unified rows.
  public func reviewCardPlacements(
    of tab: AllChangesTab,
    onWholeFile path: String,
    in lines: [DiffLine],
  ) -> [ReviewCardPlacement] {
    let sources = reviewCardSources(of: tab.id, in: tab.worktreeID, side: nil)
    return ReviewCardPlacement.placements(
      of: sources.comments(onFile: path),
      selected: selectedReviewComments[tab.worktreeID],
      composer: sources.composer(onFile: path),
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
