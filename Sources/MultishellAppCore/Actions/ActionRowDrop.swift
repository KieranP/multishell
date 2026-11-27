/// Where a dragged row of the Actions page lands: before or after the row the
/// pointer is over.
public struct ActionRowDrop: Equatable, Sendable {
  public let row: Int
  public let isAfter: Bool

  public init(row: Int, isAfter: Bool) {
    self.row = row
    self.isAfter = isAfter
  }

  /// The index the moved row ends at; `nil` where it would stay where it is,
  /// which draws no line.
  public func destination(movingFrom source: Int) -> Int? {
    let gap = isAfter ? row + 1 : row
    let destination = gap > source ? gap - 1 : gap
    return destination == source ? nil : destination
  }
}
