import MultishellCore

/// Each file's own part of the document, for the per-file list.
extension AllChangesDocument {
  /// `digest` is the whole file's committed side, which a fold opening leaves as it was.
  private static func rows(
    _ rows: Range<Int>,
    of text: DiffDisplayText,
    digest: Int?,
  ) -> DiffDisplayText {
    DiffDisplayText(
      rows.map(text.uncutLine(ofRow:)),
      wholeSides: text.wholeSides,
      committedDigest: digest,
      marksStaging: text.marksStaging,
      changeBreaks: Set(text.changeBreaks.filter(rows.contains).map { $0 - rows.lowerBound }),
    )
  }

  /// The file at `index`; one shown whole in Split gives its Unified rows.
  public func slice(ofSection index: Int) -> AllChangesFileSlice {
    let section = sections[index]
    let gapItems = gapItems(ofSection: index)
    if section.isShownWhole, let fileText = section.fileText {
      return AllChangesFileSlice(
        section: index,
        text: fileText,
        committedText: nil,
        gapItems: gapItems,
      )
    }
    let rows = section.rows
    return AllChangesFileSlice(
      section: index,
      text: Self.rows(rows, of: text, digest: section.fileText?.committedDigest),
      committedText: committedText.map { committed in
        Self.rows(rows, of: committed, digest: section.fileCommittedText?.committedDigest)
      },
      gapItems: gapItems.map { item in
        AllChangesGapItem(
          afterRow: max(-1, item.afterRow - rows.lowerBound),
          section: item.section,
          kind: item.kind,
        )
      },
    )
  }
}
