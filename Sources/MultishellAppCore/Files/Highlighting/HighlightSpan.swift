/// One highlighted range of a text, in UTF-16 units.
public struct HighlightSpan: Hashable, Sendable {
  public let range: Range<Int>
  public let role: HighlightRole

  public init(range: Range<Int>, role: HighlightRole) {
    self.range = range
    self.role = role
  }
}
