import Foundation
import MultishellAppCore
import SwiftTreeSitter

/// A Markdown file's HTML blocks, read as one HTML document with the Markdown between
/// them blanked, so a later block's `</details>` closes what an earlier one opened.
enum HTMLBlocks {
  typealias Block = (range: Range<Int>, lineMarkers: [Range<Int>])

  /// CommonMark's processing instruction and CDATA blocks, which HTML's grammar misreads.
  private static let foreignOpeners = ["<?", "<![CDATA["]

  private static let longestForeignOpener = foreignOpeners.map(\.utf16.count).max() ?? 0

  static func injection(of htmlBlocks: [Node], under root: Node, in text: NSString) -> Injection? {
    let blocks =
      (htmlBlocks.compactMap { node in block(node, in: text) }
      + HeadingTagBlocks.blocks(under: root, in: text))
      .sorted { $0.range.lowerBound < $1.range.lowerBound }
    guard let first = blocks.first?.range, let last = blocks.last?.range else { return nil }
    let ranges = blocks.map(\.range)
    let between = zip(ranges, ranges.dropFirst()).map { $0.upperBound..<$1.lowerBound }
    return Injection(
      range: first.lowerBound..<last.upperBound,
      language: .html,
      blankedRanges: blocks.flatMap(\.lineMarkers),
      hostRanges: between.filter { !$0.isEmpty },
    )
  }

  private static func block(_ node: Node, in text: NSString) -> Block? {
    // A block may run into the newline the grammar was given past the text.
    let range = node.range.integerRange.clamped(to: 0..<text.length)
    guard !range.isEmpty else { return nil }
    var start = range.lowerBound
    while start < range.upperBound, ASCIIUnits.indent.contains(text.character(at: start)) {
      start += 1
    }
    let opening = text.substring(
      with: NSRange((start..<range.upperBound).prefix(longestForeignOpener))
    )
    return foreignOpeners.contains { opening.hasPrefix($0) } ? nil : (range, node.lineMarkerRanges)
  }
}
