/// What sits between two rows of the All changes tab's text, hosted in a gap
/// as a review card is, so find, copy and the steps see rows only.
public struct AllChangesGapItem: Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    case header
    /// Unchanged rows of the file left out, by its own rows, and the file's
    /// own lines they hold for the label.
    case fold(fileRows: Range<Int>, lines: ClosedRange<Int>)
    case notice(AllChangesNotice)
    /// In Split, a file only added or only removed, shown Unified across both
    /// columns rather than on one side with the other blank.
    case wholeFile
  }

  /// The document row it sits under, -1 above the first.
  public let afterRow: Int
  public let section: Int
  public let kind: Kind
}
