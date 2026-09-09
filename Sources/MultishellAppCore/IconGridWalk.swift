import Foundation
import MultishellCore

/// Where an arrow key moves in the icon palette, kept apart from the view so
/// it can be tested. The palette is a grid per group, so a group always
/// starts a new row and its last row is usually short: walking one flat list
/// of every symbol instead drifts a column at each of those boundaries.
public enum IconGridWalk {
  public enum Step: Sendable {
    case left, right, up, down
  }

  /// The groups laid out as the grid draws them, `columns` wide.
  public static func rows(of groups: [ProjectIcon.Group], columns: Int) -> [[String]] {
    guard columns > 0 else { return [] }
    return groups.flatMap { group in
      stride(from: 0, to: group.glyphs.count, by: columns).map {
        Array(group.glyphs[$0..<min($0 + columns, group.glyphs.count)])
      }
    }
  }

  /// The symbol `step` lands on from `highlighted`, or `nil` when there is
  /// nowhere to go. Left and right run on through the rows; up and down hold
  /// the column, taking the last of a shorter row. With nothing highlighted,
  /// or one a search has dropped, the first key lands on the first symbol
  /// rather than a step past it.
  public static func destination(
    from highlighted: String?, step: Step, in rows: [[String]]
  ) -> String? {
    // An empty row is no landing place, and taking the last cell of one
    // indexes past its own start.
    let rows = rows.filter { !$0.isEmpty }
    guard let start = rows.first?.first else { return nil }
    guard var (row, column) = position(of: highlighted, in: rows) else { return start }
    switch step {
    case .left:
      if column > 0 {
        column -= 1
      } else if row > 0 {
        row -= 1
        column = rows[row].count - 1
      }
    case .right:
      if column + 1 < rows[row].count {
        column += 1
      } else if row + 1 < rows.count {
        row += 1
        column = 0
      }
    case .up:
      guard row > 0 else { return rows[row][column] }
      row -= 1
      column = min(column, rows[row].count - 1)
    case .down:
      guard row + 1 < rows.count else { return rows[row][column] }
      row += 1
      column = min(column, rows[row].count - 1)
    }
    return rows[row][column]
  }

  private static func position(of name: String?, in rows: [[String]]) -> (Int, Int)? {
    guard let name else { return nil }
    for (row, glyphs) in rows.enumerated() {
      if let column = glyphs.firstIndex(of: name) { return (row, column) }
    }
    return nil
  }
}
