/// One file's part of the document for its own view: its shown rows and what
/// sits between them, numbered by its own rows.
public struct AllChangesFileSlice: Equatable, Sendable {
  /// The document's section it is.
  public let section: Int
  /// The rows shown: Unified's, or Split's right side.
  public let text: DiffDisplayText
  /// Split's left side, row for row; `nil` in Unified or for a file shown whole.
  public let committedText: DiffDisplayText?
  /// Its folds and notices, each under a row of `text`, -1 above the first.
  public let gapItems: [AllChangesGapItem]

  /// Its two sides as a split view takes them; `nil` where it is Unified.
  public var split: SplitDiff? {
    committedText.map { SplitDiff(committed: $0, onDisk: text) }
  }
}
