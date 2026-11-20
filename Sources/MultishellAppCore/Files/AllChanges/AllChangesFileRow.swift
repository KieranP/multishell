/// A row of the All changes list: its file's section and the row in that
/// file's view. A change's stop is its first row.
public struct AllChangesFileRow: Equatable, Sendable {
  public let section: Int
  public let row: Int

  public init(section: Int, row: Int) {
    self.section = section
    self.row = row
  }
}
