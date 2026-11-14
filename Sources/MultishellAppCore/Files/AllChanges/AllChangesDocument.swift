import MultishellCore

/// The All changes tab's rows as one text: each file's shown rows end to end,
/// unchanged runs folded and collapsed files left out, with the headers, folds
/// and notices that sit between rows; see Docs/design/files/all-changes-tab.md.
public struct AllChangesDocument: Equatable, Sendable {
  /// Lines kept either side of a change, as `git diff` keeps them.
  static let contextLines = 3
  /// A shorter run of unchanged lines shows whole: its fold row would save little.
  static let shortestFold = 4

  static let empty = Self(
    text: .empty,
    committedText: nil,
    sections: [],
    gapItems: [],
    lineCounts: FileLineCounts(insertions: 0, deletions: 0),
  )

  /// Unified's rows, or Split's right side, the file on disk: what find searches.
  public let text: DiffDisplayText
  /// Split's left side, row for row with `text`; `nil` in Unified.
  public let committedText: DiffDisplayText?
  public let sections: [AllChangesSection]
  /// In document order, each section's header before what follows it.
  public let gapItems: [AllChangesGapItem]
  public let lineCounts: FileLineCounts

  /// Split's two sides as a split view takes them; `nil` in Unified.
  public var split: SplitDiff? {
    committedText.map { SplitDiff(committed: $0, onDisk: text) }
  }

  /// Whether a shown row changed, which the bar's arrows step between.
  public var hasChanges: Bool { !text.changeStarts.isEmpty }

  private init(
    text: DiffDisplayText,
    committedText: DiffDisplayText?,
    sections: [AllChangesSection],
    gapItems: [AllChangesGapItem],
    lineCounts: FileLineCounts,
  ) {
    self.text = text
    self.committedText = committedText
    self.sections = sections
    self.gapItems = gapItems
    self.lineCounts = lineCounts
  }

  /// `collapsed` names files showing their header alone; `heldOpen` the lines
  /// each file keeps out of its folds. Split lays each file's two sides row for
  /// row, a file only added or removed padded opposite.
  init(
    _ reading: AllChangesReading,
    collapsed: Set<String>,
    heldOpen: [String: [AllChangesLineSpan]],
    layout: FileTabLayout = .unified,
  ) {
    var builder = AllChangesDocumentBuilder(layout: layout)
    for file in reading.files {
      builder.add(
        file,
        isCollapsed: collapsed.contains(file.path),
        heldOpen: heldOpen[file.path] ?? [],
      )
    }
    self.init(
      text: builder.text(marksStaging: true),
      committedText: builder.committedText(marksStaging: true),
      sections: builder.sections,
      gapItems: builder.gapItems,
      lineCounts: reading.lineCounts,
    )
  }

  /// The file a row is in, by halving over the sections' rows.
  public func section(atRow row: Int) -> Int? {
    let index = sections.partitioningIndex { $0.headerAfterRow >= row }
    return index > 0 ? index - 1 : nil
  }

  /// The file and its own row a document row shows.
  func location(ofRow row: Int) -> (section: Int, fileRow: Int)? {
    guard let section = section(atRow: row),
      let fileRow = sections[section].fileRow(ofDocumentRow: row)
    else { return nil }
    return (section, fileRow)
  }

  /// The files whose rows `rows` reach, `nil` where it reaches none.
  public func sections(reaching rows: Range<Int>) -> ClosedRange<Int>? {
    guard let first = rows.first, let last = rows.last,
      let top = section(atRow: first), let bottom = section(atRow: last)
    else { return nil }
    return top...bottom
  }

  /// The header of the section at `index`, as `gapItems` lists it.
  public func headerItem(ofSection index: Int) -> AllChangesGapItem {
    AllChangesGapItem(afterRow: sections[index].headerAfterRow, section: index, kind: .header)
  }

  public func section(at path: String) -> Int? {
    sections.firstIndex { $0.path == path }
  }
}
