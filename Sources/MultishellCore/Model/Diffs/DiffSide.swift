/// Which text a row's line comes from, for parsing each in one piece. The raw
/// values are saved with review comments, so they never change.
public enum DiffSide: String, Codable, Hashable, Sendable {
  /// The committed side's, `HEAD` or the merge base: kept and removed lines.
  case committed
  /// The file on disk's: kept and added lines.
  case onDisk
}
