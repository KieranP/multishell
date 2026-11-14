import MultishellCore

/// Every file's shown rows end to end, with the folds and notices between them;
/// see Docs/design/files/all-changes-tab.md.
public struct AllChangesDocument: Equatable, Sendable {
  /// Lines kept either side of a change, as `git diff` keeps them.
  static let contextLines = 3
  /// A shorter run of unchanged lines shows whole: its fold row would save little.
  static let shortestFold = 4

  /// Unified's rows, or Split's right side, the file on disk: what find searches.
  public let text: DiffDisplayText
  /// Split's left side, row for row with `text`; `nil` in Unified.
  let committedText: DiffDisplayText?
  public let sections: [AllChangesSection]
  /// In document order.
  let gapItems: [AllChangesGapItem]
  /// The same by file, which each file's view and estimate ask for as the list scrolls.
  private let gapItemsBySection: [Int: [AllChangesGapItem]]
  /// Each file's section, which the sticky header asks after on every scroll frame.
  private let sectionByPath: [String: Int]
  public let lineCounts: FileLineCounts

  /// Split's two sides as a split view takes them; `nil` in Unified.
  var split: SplitDiff? {
    committedText.map { SplitDiff(committed: $0, onDisk: text) }
  }

  /// Whether a shown row changed or a file waits to be read, which the bar's
  /// arrows step between.
  public var hasChanges: Bool {
    !text.changeStarts.isEmpty || gapItems.contains { $0.kind == .notice(.reading) }
  }

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
    gapItemsBySection = Dictionary(grouping: gapItems, by: \.section)
    sectionByPath = Dictionary(keepingFirst: sections.enumerated().map { ($1.path, $0) })
    self.lineCounts = lineCounts
  }

  /// `collapsed` names files showing their header alone; `heldOpen` the lines
  /// each file keeps out of its folds.
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

  /// Whether a file's view shows Split's two columns; one shown whole is
  /// Unified across them.
  public func showsSplitColumns(ofSection index: Int) -> Bool {
    split != nil && !sections[index].isShownWhole
  }

  public func gapItems(ofSection index: Int) -> [AllChangesGapItem] {
    gapItemsBySection[index] ?? []
  }

  public func section(at path: String) -> Int? {
    sectionByPath[path]
  }
}
