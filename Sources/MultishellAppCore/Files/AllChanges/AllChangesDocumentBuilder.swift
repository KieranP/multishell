import MultishellCore

/// Lays the All changes tab's files end to end, one at a time, into the rows
/// and gaps `AllChangesDocument` holds: Unified's one text, or Split's two,
/// row for row.
struct AllChangesDocumentBuilder {
  /// Unified's rows, or Split's right side.
  private var lines: [DiffLine] = []
  /// Split's left side, `nil` in Unified.
  private var committedLines: [DiffLine]?
  private var changeBreaks: Set<Int> = []
  private(set) var sections: [AllChangesSection] = []
  private(set) var gapItems: [AllChangesGapItem] = []
  /// Whether any file's rows marked staging, which every file read under one base shares.
  private var marksStaging: Bool?

  init(layout: FileTabLayout) {
    committedLines = layout == .split ? [] : nil
  }

  /// Rows within the context of a change or held open, and every row of an
  /// unchanged run too short to fold.
  private static func keptRows(of lines: [DiffLine], heldOpen: [AllChangesLineSpan]) -> [Bool] {
    var kept = [Bool](repeating: false, count: lines.count)
    for (row, line) in lines.enumerated() {
      if line.kind != .context {
        let first = max(0, row - AllChangesDocument.contextLines)
        let last = min(lines.count - 1, row + AllChangesDocument.contextLines)
        for near in first...last { kept[near] = true }
      } else if heldOpen.contains(where: { $0.holds(line) }) {
        kept[row] = true
      }
    }
    var row = 0
    while row < lines.count {
      guard !kept[row] else {
        row += 1
        continue
      }
      var end = row
      while end < lines.count, !kept[end] { end += 1 }
      if end - row < AllChangesDocument.shortestFold {
        for short in row..<end { kept[short] = true }
      }
      row = end
    }
    return kept
  }

  /// A line cut for the file's display is cut again by the document's, so it
  /// is handed over whole and a copy still takes it whole.
  private static func uncut(_ text: DiffDisplayText, row: Int) -> DiffLine {
    let line = text.lines[row]
    guard text.cutRemainders[row] != nil else { return line }
    return DiffLine(
      kind: line.kind,
      oldNumber: line.oldNumber,
      newNumber: line.newNumber,
      text: text.uncutText(ofRow: row),
      isStaged: line.isStaged,
      changedParts: line.changedParts,
    )
  }

  private static func notice(for content: AllChangesFileContent) -> AllChangesNotice {
    switch content {
    case .pastRowCap: return .pastRowCap
    case .unread: return .reading

    case .read(let reading):
      switch reading.content {
      case .binary(let bytes): return .binary(bytes: bytes)
      case .image: return .image
      case .missing: return .missing
      case .released, .releasedFollowingStatus: return .reading
      case .text: return .empty
      case .tooLarge(let bytes): return .tooLarge(bytes: bytes)
      case .unreadable: return .unreadable
      }
    }
  }

  /// One split row as the folds judge it: unchanged only where both sides are,
  /// numbered by the left's committed line and the right's line on disk.
  private static func pairedRows(
    _ committed: DiffDisplayText,
    _ onDisk: DiffDisplayText,
  ) -> [DiffLine] {
    zip(committed.lines, onDisk.lines).map { left, right in
      DiffLine(
        kind: left.kind == .context && right.kind == .context ? .context : .added,
        oldNumber: left.oldNumber,
        newNumber: right.newNumber,
        text: "",
      )
    }
  }

  private static func text(
    _ lines: [DiffLine],
    marksStaging: Bool,
    changeBreaks: Set<Int>,
  ) -> DiffDisplayText {
    DiffDisplayText(
      lines,
      wholeSides: [],
      committedDigest: 0,
      marksStaging: marksStaging,
      changeBreaks: changeBreaks,
    )
  }

  /// Unified's text, or Split's right side.
  func text(marksStaging fallback: Bool) -> DiffDisplayText {
    Self.text(lines, marksStaging: marksStaging ?? fallback, changeBreaks: changeBreaks)
  }

  /// Split's left side, `nil` in Unified.
  func committedText(marksStaging fallback: Bool) -> DiffDisplayText? {
    committedLines.map { lines in
      Self.text(lines, marksStaging: marksStaging ?? fallback, changeBreaks: changeBreaks)
    }
  }

  mutating func add(_ file: AllChangesFile, isCollapsed: Bool, heldOpen: [AllChangesLineSpan]) {
    let section = sections.count
    let headerAfterRow = lines.count - 1
    gapItems.append(AllChangesGapItem(afterRow: headerAfterRow, section: section, kind: .header))
    let rows = isCollapsed ? nil : file.rows
    // A file with no line changed has no split; its unchanged rows read alike on both sides.
    let onDisk =
      committedLines == nil ? rows?.displayText : rows.map { $0.split?.onDisk ?? $0.displayText }
    let committed = committedLines == nil ? nil : rows.map { $0.split?.committed ?? $0.displayText }
    var fileRows: [Int] = []
    let isShownWhole = committedLines != nil && rows?.isOneSided == true
    if let rows, isShownWhole {
      gapItems.append(
        AllChangesGapItem(afterRow: headerAfterRow, section: section, kind: .wholeFile)
      )
      marksStaging = marksStaging ?? rows.displayText.marksStaging
    } else if let rows, let onDisk {
      marksStaging = marksStaging ?? rows.displayText.marksStaging
      if rows.lines.isEmpty {
        gapItems.append(
          AllChangesGapItem(afterRow: headerAfterRow, section: section, kind: .notice(.empty))
        )
      } else {
        changeBreaks.insert(lines.count)
        fileRows = append(onDisk, beside: committed, of: section, heldOpen: heldOpen)
      }
    } else if !isCollapsed {
      gapItems.append(
        AllChangesGapItem(
          afterRow: headerAfterRow,
          section: section,
          kind: .notice(Self.notice(for: file.content)),
        )
      )
    }
    sections.append(
      AllChangesSection(
        change: file.change,
        lineCounts: file.rows?.lineCounts ?? file.change.lineCounts,
        isCollapsed: isCollapsed,
        rows: (headerAfterRow + 1)..<lines.count,
        fileRows: fileRows,
        fileText: isShownWhole ? rows?.displayText : onDisk,
        fileCommittedText: isShownWhole ? nil : committed,
        isShownWhole: isShownWhole,
        headerAfterRow: headerAfterRow,
      )
    )
  }

  /// The rows kept, each side's where Split, each unchanged run folded where
  /// long enough, and returns each kept row's index in the file's rows.
  private mutating func append(
    _ text: DiffDisplayText,
    beside committed: DiffDisplayText?,
    of section: Int,
    heldOpen: [AllChangesLineSpan],
  ) -> [Int] {
    let judged = committed.map { Self.pairedRows($0, text) } ?? text.lines
    let kept = Self.keptRows(of: judged, heldOpen: heldOpen)
    var fileRows: [Int] = []
    var row = 0
    while row < text.lines.count {
      guard !kept[row] else {
        fileRows.append(row)
        lines.append(Self.uncut(text, row: row))
        if let committed { committedLines?.append(Self.uncut(committed, row: row)) }
        row += 1
        continue
      }
      var end = row
      while end < text.lines.count, !kept[end] { end += 1 }
      let numbers = text.lines[row..<end].compactMap(\.newNumber)
      if let first = numbers.first, let last = numbers.last {
        gapItems.append(
          AllChangesGapItem(
            afterRow: lines.count - 1,
            section: section,
            kind: .fold(fileRows: row..<end, lines: first...last),
          )
        )
      }
      row = end
    }
    return fileRows
  }
}
