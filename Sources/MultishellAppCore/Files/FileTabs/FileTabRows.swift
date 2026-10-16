/// A file tab's rows, and what its bar counts: the counts come from the diff
/// the tab drew, so the bar and the rows cannot disagree.
public struct FileTabRows: Equatable, Sendable {
  /// Built once a read, a file's worth of rows being costly to join.
  public let displayText: DiffDisplayText
  /// The two sides a split shows, `nil` for a file with no line changed.
  let split: SplitDiff?
  /// Only the mode changed: the rows are plain, with a note and no switch.
  public let hasModeChange: Bool
  public let lineCounts: FileLineCounts

  var lines: [DiffLine] { displayText.lines }
  public var hasLineChanges: Bool { !lineCounts.isEmpty }
  /// False where every row is `HEAD`'s, removed: a deleted file's.
  var holdsTextOnDisk: Bool { lines.contains { $0.kind != .removed } }

  init(lines unmarked: [DiffLine], hasModeChange: Bool = false) {
    let lines = ChangedPartsMarker.marking(unmarked)
    displayText = DiffDisplayText(lines)
    split = lines.contains(where: \.isChange) ? SplitDiff(lines) : nil
    self.hasModeChange = hasModeChange
    lineCounts = FileLineCounts(
      insertions: lines.count { $0.kind == .added },
      deletions: lines.count { $0.kind == .removed },
    )
  }

  /// The file as it last stood on disk, every change unmarked: what a tab
  /// keeps showing once its file is deleted.
  func lastTextOnDisk() -> Self {
    var number = 0
    return Self(
      lines: lines.filter { $0.kind != .removed }.map { line in
        number += 1
        return DiffLine(kind: .context, oldNumber: nil, newNumber: number, text: line.text)
      }
    )
  }
}
