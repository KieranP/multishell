/// git's own test for a binary file, which the line counts and a file tab both
/// follow so the two agree on what has lines.
public enum GitBinaryRule {
  /// A zero byte in this many bytes from the start makes a file binary.
  public static let checkedByteCount = 8000
}
