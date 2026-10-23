/// The boxed change by its text and place, not its row, and `HEAD` by digest to
/// tell a commit from an edit; why is in Docs/design/files.md.
public struct ChangeAnchor: Equatable, Sendable {
  let headDigest: Int
  let headLineAbove: Int
  /// The `HEAD` line just below it, `nil` at the end.
  let headLineBelow: Int?
  /// The unchanged line just above it, `nil` at the top.
  let textAbove: String?
  /// Its first line with a letter or digit on the side that boxed it, `nil`
  /// where it has none: `}` or a blank line repeats across a file.
  let lineText: String?
}
