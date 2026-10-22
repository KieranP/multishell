/// `HEAD` beside the file on disk, row for row: each run of removed lines beside
/// the added run that replaced it, the shorter padded.
public struct SplitDiff: Equatable, Sendable {
  public let committed: DiffDisplayText
  public let onDisk: DiffDisplayText

  init(_ lines: [DiffLine]) {
    var left: [DiffLine] = []
    var right: [DiffLine] = []
    var removed: [DiffLine] = []
    var added: [DiffLine] = []
    func flush() {
      let rows = max(removed.count, added.count)
      left += removed + Array(repeating: .padding, count: rows - removed.count)
      right += added + Array(repeating: .padding, count: rows - added.count)
      removed = []
      added = []
    }
    for line in lines {
      switch line.kind {
      case .added: added.append(line)
      case .removed: removed.append(line)

      case .context, .padding:
        flush()
        left.append(line)
        right.append(line)
      }
    }
    flush()
    committed = DiffDisplayText(left, wholeSides: [.committed])
    onDisk = DiffDisplayText(right, wholeSides: [.onDisk])
  }
}
