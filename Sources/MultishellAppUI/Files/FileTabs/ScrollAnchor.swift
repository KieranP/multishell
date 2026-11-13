import AppKit

/// Where a document view's clip starts: a row, and how far below that row's top.
struct ScrollAnchor {
  let row: Int
  let offsetBelowRow: CGFloat
}
