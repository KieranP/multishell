import MultishellAppCore
import SwiftTreeSitter

extension Node {
  /// A Markdown quote's `>` marker or list item's indent, which the grammar repeats on each line.
  var isLineMarker: Bool { nodeType == "block_continuation" }

  /// The non-empty line markers among its children: every line's but its first, and in an
  /// `html_block` the next line's too, the grammar closing the block after it.
  var lineMarkerRanges: [Range<Int>] {
    children.filter(\.isLineMarker).map(\.range.integerRange).filter { !$0.isEmpty }
  }
}
