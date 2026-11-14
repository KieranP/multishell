import MultishellCore

/// One file of the All changes tab as its text lays it out.
public struct AllChangesSection: Equatable, Sendable {
  public let change: AllChangesFileChange
  /// Its rows' counts where it has rows, else the Changes list's.
  public let lineCounts: FileLineCounts?
  public let isCollapsed: Bool
  /// The document rows its shown rows take, empty where it shows none.
  public let rows: Range<Int>
  /// Each of those rows' index in the file's own rows, ascending.
  let fileRows: [Int]
  /// The file's own rows, folded or not, which highlighting, anchoring and a
  /// saved scroll read; `nil` where it has none.
  public let fileText: DiffDisplayText?
  /// Split's left side of the file, row for row with `fileText`; `nil` in Unified.
  public let fileCommittedText: DiffDisplayText?
  /// In Split, a file only added or removed, its Unified rows in `fileText`
  /// shown across both columns and none in either.
  public let isShownWhole: Bool
  /// Where its header sits: under this document row, -1 above the first.
  public let headerAfterRow: Int

  public var path: String { change.path }

  /// What carries a boxed change within the file: its text, or its two sides.
  var fileAnchoring: (any ChangeAnchoring)? {
    guard let fileText else { return nil }
    return fileCommittedText.map { SplitDiff(committed: $0, onDisk: fileText) } ?? fileText
  }

  /// One column's side of the file: Split's left for the committed side.
  public func sideText(on side: DiffSide?) -> DiffDisplayText? {
    side == .committed ? fileCommittedText ?? fileText : fileText
  }

  /// The document row showing `fileRow`, else the next one shown after it.
  func documentRow(atOrAfterFileRow fileRow: Int) -> Int? {
    let index = fileRows.partitioningIndex { $0 >= fileRow }
    return fileRows.indices.contains(index) ? rows.lowerBound + index : nil
  }

  func fileRow(ofDocumentRow row: Int) -> Int? {
    rows.contains(row) ? fileRows[row - rows.lowerBound] : nil
  }

  /// The document row showing `fileRow`, `nil` where a fold hides it.
  public func documentRow(ofFileRow fileRow: Int) -> Int? {
    let index = fileRows.partitioningIndex { $0 >= fileRow }
    guard fileRows.indices.contains(index), fileRows[index] == fileRow else { return nil }
    return rows.lowerBound + index
  }
}
