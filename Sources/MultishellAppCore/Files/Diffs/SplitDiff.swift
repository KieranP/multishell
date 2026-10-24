/// The committed side beside the file on disk, row for row: each run of removed lines beside
/// the added run that replaced it, the shorter padded.
public struct SplitDiff: Equatable, Sendable {
  public let committed: DiffDisplayText
  public let onDisk: DiffDisplayText

  /// `committedDigest` is the Unified text's where it was already hashed.
  init(_ lines: [DiffLine], marksStaging: Bool, committedDigest: Int? = nil) {
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
    committed = DiffDisplayText(
      left,
      wholeSides: [.committed],
      committedDigest: committedDigest,
      marksStaging: marksStaging,
    )
    onDisk = DiffDisplayText(
      right,
      wholeSides: [.onDisk],
      committedDigest: committed.committedDigest,
      marksStaging: marksStaging,
    )
  }
}
