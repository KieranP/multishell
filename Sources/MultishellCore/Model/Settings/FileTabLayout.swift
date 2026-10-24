/// How a file tab draws changed lines, inline or the committed side beside the
/// file on disk; one saved choice for every tab, so raw values never change.
public enum FileTabLayout: String, Codable, Hashable, Sendable {
  case split
  case unified

  static let `default` = Self.unified
}
