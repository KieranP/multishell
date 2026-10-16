/// How a file tab draws changed lines, inline or `HEAD` beside the file on
/// disk; one saved choice for every tab, so raw values never change.
public enum FileTabLayout: String, Codable, Hashable, Sendable, CaseIterable {
  case split
  case unified

  public static let `default` = Self.unified
}
