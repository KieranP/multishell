import AppKit
import MultishellAppCore

/// Gaps opened under rows for review cards, by the row they follow, summed
/// once so a row's top is a binary search rather than a walk of a 1 MiB file.
struct RowGaps: Equatable {
  static let empty = Self([:])

  /// Ascending by row.
  private let rows: [Int]
  private let heights: [CGFloat]
  /// `heightsAbove[i]` is every gap before the `i`th; one longer than `rows`.
  private let heightsAbove: [CGFloat]

  var total: CGFloat { heightsAbove.last ?? 0 }

  /// A height of zero or less opens no gap.
  init(_ heightsByRow: [Int: CGFloat]) {
    let kept = heightsByRow.filter { $0.value > 0 }.sorted { $0.key < $1.key }
    rows = kept.map(\.key)
    heights = kept.map(\.value)
    var sum: CGFloat = 0
    var above: [CGFloat] = [0]
    for height in heights {
      sum += height
      above.append(sum)
    }
    heightsAbove = above
  }

  /// The gap opened under `row`, 0 where none is.
  func height(under row: Int) -> CGFloat {
    let index = gapsBefore(row: row)
    return rows.indices.contains(index) && rows[index] == row ? heights[index] : 0
  }

  /// Every gap under a row above `row`.
  func heightAbove(row: Int) -> CGFloat {
    heightsAbove[gapsBefore(row: row)]
  }

  /// Where `y`, measured from the first row's top, falls: a fractional row,
  /// or the row after a gap for a point inside it.
  func row(atContentY y: CGFloat, rowHeight: CGFloat) -> Double {
    // The gaps wholly above `y`: a gap's top is its row's end plus every gap before it.
    let low = rows.indices.partitioningIndex { index in
      CGFloat(rows[index] + 1) * rowHeight + heightsAbove[index] > y
    }
    guard low > 0 else { return Double(y / rowHeight) }
    let index = low - 1
    let gapTop = CGFloat(rows[index] + 1) * rowHeight + heightsAbove[index]
    if y < gapTop + heights[index] { return Double(rows[index] + 1) }
    return Double((y - heightsAbove[low]) / rowHeight)
  }

  /// How many gaps sit under rows before `row`.
  private func gapsBefore(row: Int) -> Int {
    rows.partitioningIndex { $0 >= row }
  }
}
