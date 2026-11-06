import Foundation
import MultishellAppCore
import SwiftTreeSitter

/// The HTML blocks Markdown's grammar misreads: it reads a block tag's name as letters
/// alone, so a line opening with `<h1>` to `<h6>` stays in a paragraph.
enum HeadingTagBlocks {
  private static let lowercaseH = UInt16(UInt8(ascii: "h"))
  private static let headingLevels = UInt16(UInt8(ascii: "1"))...UInt16(UInt8(ascii: "6"))
  private static let tagNameEnders = Set(" \t>\n\r".utf16)
  private static let tab = UInt16(UInt8(ascii: "\t"))
  private static let tabStop = 4
  private static let containerTypes: Set = [
    "document", "section", "block_quote", "list", "list_item",
  ]

  /// The indent CommonMark allows before a block's tag, in columns.
  private static let maximumIndent = 3

  /// Each from its tag to its paragraph's end. Searched for in the text, as capturing
  /// every paragraph cost 7% of finding a 1 MiB file's injections.
  static func blocks(under root: Node, in text: NSString) -> [HTMLBlocks.Block] {
    var blocks: [HTMLBlocks.Block] = []
    // Read once a paragraph: a quoted one mentioning `<h1>` on each of 10,000 lines
    // read its markers again for every mention and ran for minutes.
    var paragraph: HTMLBlocks.Block?
    var searched = 0..<text.length
    while !searched.isEmpty {
      let found = text.range(of: "<", options: .literal, range: NSRange(searched))
      guard found.location != NSNotFound else { break }
      let tag = found.location
      searched = (tag + 1)..<text.length
      guard opensHeadingTag(at: tag, in: text) else { continue }
      if paragraph?.range.contains(tag) != true {
        guard let block = block(holding: tag, under: root) else { continue }
        // Skipped whole, as a fence of 30,000 `<h1>` lines took 0.43 s looked up line by line.
        guard block.nodeType == "paragraph" else {
          searched = min(block.range.integerRange.upperBound, text.length)..<text.length
          continue
        }
        paragraph = rangeAndMarkers(of: block, in: text)
      }
      guard let paragraph, opensItsLine(tag, in: paragraph, of: text) else { continue }
      let lineMarkers = paragraph.lineMarkers.filter { $0.lowerBound > tag }
      blocks.append((tag..<paragraph.range.upperBound, lineMarkers))
      searched = paragraph.range.upperBound..<text.length
    }
    return blocks
  }

  /// `h1` to `h6` are CommonMark's only block tags with a digit.
  private static func opensHeadingTag(at index: Int, in text: NSString) -> Bool {
    func unit(_ offset: Int) -> UInt16? {
      index + offset < text.length ? text.character(at: index + offset) : nil
    }
    let name = unit(1) == ASCIIUnits.slash ? 2 : 1
    guard let letter = unit(name), letter | ASCIIUnits.lowercaseBit == lowercaseH,
      let level = unit(name + 1), headingLevels.contains(level)
    else { return false }
    guard let next = unit(name + 2) else { return true }
    return tagNameEnders.contains(next)
      || (next == ASCIIUnits.slash && unit(name + 3) == ASCIIUnits.greaterThan)
  }

  /// The paragraph holding `offset`, or else the block holding it that no container is;
  /// none where `offset` falls in a container itself.
  private static func block(holding offset: Int, under root: Node) -> Node? {
    var node = root.descendant(in: NSRange(location: offset, length: 1).byteRange)
    while let current = node, current.nodeType != "paragraph", let parent = current.parent,
      !isContainer(parent)
    {
      node = parent
    }
    guard let node, !isContainer(node) else { return nil }
    return node
  }

  private static func isContainer(_ node: Node) -> Bool {
    node.nodeType.map(containerTypes.contains) ?? false
  }

  /// Its later lines' markers sit in its inline content, and the next line's after it.
  private static func rangeAndMarkers(of paragraph: Node, in text: NSString) -> HTMLBlocks.Block {
    let inline = paragraph.children.first { $0.nodeType == "inline" }
    let lineMarkers = ((inline?.lineMarkerRanges ?? []) + paragraph.lineMarkerRanges)
      .sorted { $0.lowerBound < $1.lowerBound }
    return (paragraph.range.integerRange.clamped(to: 0..<text.length), lineMarkers)
  }

  /// Whether no more than CommonMark's indent stands between the tag and its container's
  /// content column, or its line's start on a lazy line, a tab running to the next stop.
  private static func opensItsLine(
    _ tag: Int,
    in paragraph: HTMLBlocks.Block,
    of text: NSString,
  ) -> Bool {
    let markers = paragraph.lineMarkers
    let markersBefore = markers.firstIndex(endingAfter: tag)
    let marker = markersBefore > 0 ? markers[markersBefore - 1] : nil
    // Walked back over indent alone, so a long line of mentions costs no more than its length.
    let floor = max(paragraph.range.lowerBound, marker?.upperBound ?? 0)
    let indentUnits = ASCIIUnits.indent
    var indentStart = tag
    while indentStart > floor, indentUnits.contains(text.character(at: indentStart - 1)) {
      indentStart -= 1
    }
    if let marker, indentStart == marker.upperBound {
      // Not from the marker's end: a marker ending in a tab takes columns past the content.
      let tagColumn = column(of: tag, from: marker.lowerBound, in: text)
      return tagColumn - contentColumn(of: paragraph.range, in: text) <= maximumIndent
    }
    // The paragraph's first line, which the grammar would have read as code if indented.
    if indentStart == paragraph.range.lowerBound { return true }
    guard ASCIIUnits.lineBreaks.contains(text.character(at: indentStart - 1)) else { return false }
    return column(of: tag, from: indentStart, in: text) <= maximumIndent
  }

  /// Where the paragraph's first line's text starts, which its container's later lines share.
  private static func contentColumn(of paragraph: Range<Int>, in text: NSString) -> Int {
    var lineStart = paragraph.lowerBound
    while lineStart > 0, !ASCIIUnits.lineBreaks.contains(text.character(at: lineStart - 1)) {
      lineStart -= 1
    }
    return column(of: paragraph.lowerBound, from: lineStart, in: text)
  }

  private static func column(of index: Int, from lineStart: Int, in text: NSString) -> Int {
    (lineStart..<index).reduce(0) { column, offset in
      text.character(at: offset) == tab ? (column / tabStop + 1) * tabStop : column + 1
    }
  }
}
