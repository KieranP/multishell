/// What sits between two rows of the All changes tab's text, hosted in a gap
/// as a review card is, so find, copy and the steps see rows only.
public struct AllChangesGapItem: Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    /// Unchanged rows of the file left out, by the file's own lines they hold.
    case fold(lines: ClosedRange<Int>)
    case notice(AllChangesNotice)
  }

  /// The document row it sits under, -1 above the first.
  public let afterRow: Int
  public let section: Int
  public let kind: Kind
}
