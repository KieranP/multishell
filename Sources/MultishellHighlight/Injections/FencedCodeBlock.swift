import Foundation
import MultishellAppCore
import SwiftTreeSitter

/// A Markdown fenced code block's body, read in the language its info string names.
enum FencedCodeBlock {
  private static let lineMarkerType = "block_continuation"

  /// None where the info string names no grammar here, the body keeping Markdown's colour.
  static func injection(of block: Node, in text: NSString) -> Injection? {
    let children = Array(block.children)
    guard let info = children.first(where: { $0.nodeType == "info_string" }),
      let name = info.children.first(where: { $0.nodeType == "language" }),
      let language = HighlightLanguage.language(forCodeFence: text.substring(with: name.range)),
      // Its own fences would recurse a level each; 200 nested overflowed a stack.
      language != .markdown,
      let bodyIndex = children.firstIndex(where: { $0.nodeType == "code_fence_content" })
    else { return nil }
    let bodyNode = children[bodyIndex]
    // An unclosed fence's body runs into the newline the grammar was given past the text.
    let body = bodyNode.range.integerRange.clamped(to: 0..<text.length)
    guard !body.isEmpty else { return nil }
    let firstLineMarker = firstLineMarker(of: body, after: children[..<bodyIndex].last)
    let laterLineMarkers = bodyNode.children.filter { $0.nodeType == lineMarkerType }
      .map(\.range.integerRange).filter { !$0.isEmpty }
    return Injection(
      range: (firstLineMarker?.lowerBound ?? body.lowerBound)..<body.upperBound,
      language: language,
      prefix: prefix(for: language, body: body, in: text),
      blankedRanges: (firstLineMarker.map { [$0] } ?? []) + laterLineMarkers,
    )
  }

  /// The body's first line's quote marker or list indent, taken in so that every line
  /// is blanked alike and none reads as nested under the first.
  private static func firstLineMarker(of body: Range<Int>, after node: Node?) -> Range<Int>? {
    guard let node, node.nodeType == lineMarkerType else { return nil }
    let range = node.range.integerRange
    return range.upperBound == body.lowerBound && !range.isEmpty ? range : nil
  }

  /// PHP's grammar reads all before `<?php` as HTML, and a fence usually leaves it out.
  private static func prefix(
    for language: HighlightLanguage,
    body: Range<Int>,
    in text: NSString,
  ) -> String {
    guard language == .php,
      text.range(of: "<?", options: .anchored, range: NSRange(body)).location == NSNotFound
    else { return "" }
    return "<?php "
  }
}
