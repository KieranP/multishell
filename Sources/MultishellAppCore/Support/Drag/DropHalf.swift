/// Which half of a drop target the pointer is in, along the axis its row or
/// strip runs. A length not yet measured reads as the leading half.
public enum DropHalf: Equatable, Sendable {
  case leading
  case trailing

  public init(at position: Double, along length: Double) {
    self = length > 0 && position >= length / 2 ? .trailing : .leading
  }
}
