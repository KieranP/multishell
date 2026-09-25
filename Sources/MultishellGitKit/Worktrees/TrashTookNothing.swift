/// The Trash reported success with the directory still in place, so the
/// removal stopped rather than let git unlink it.
public struct TrashTookNothing: Error, CustomStringConvertible {
  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String { "the directory is still there" }
}
