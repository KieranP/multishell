/// Which text a row's line comes from, for parsing each in one piece.
public enum DiffSide: Hashable, Sendable {
  /// The committed side's, `HEAD` or the merge base: kept and removed lines.
  case committed
  /// The file on disk's: kept and added lines.
  case onDisk

  func shows(_ kind: DiffLine.Kind) -> Bool {
    switch kind {
    case .context: true
    case .added: self == .onDisk
    case .removed: self == .committed
    case .padding: false
    }
  }
}
