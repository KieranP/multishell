/// Why a file of the All changes tab shows its header and no rows.
public enum AllChangesNotice: Hashable, Sendable {
  case binary(bytes: Int)
  /// A file with no lines, an empty file added.
  case empty
  case image
  case missing
  /// Past the rows the tab holds in all.
  case pastRowCap
  /// Listed, its read still to come.
  case reading
  /// Past a file tab's cap, on disk or on the committed side.
  case tooLarge(bytes: Int)
  case unreadable
}
