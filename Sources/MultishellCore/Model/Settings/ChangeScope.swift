/// What the Git list and every file tab count a change from: `HEAD`, or where
/// the branch left its base. One saved choice, so raw values never change.
public enum ChangeScope: String, Codable, Hashable, Sendable {
  case branch
  case modified

  static let `default` = Self.modified
}
