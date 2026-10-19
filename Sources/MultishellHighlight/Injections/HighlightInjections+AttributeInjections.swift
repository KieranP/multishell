import Foundation
import MultishellAppCore
import SwiftTreeSitter

extension HighlightInjections {
  /// Each `style` and `on…` attribute the text scan finds, the first of a name in any case
  /// on an element alone, as a browser keeps it; Svelte 5 hands it the static ones as written.
  static func attributeInjections(
    under root: Node,
    text: NSString,
    host: MarkupHost,
    within keptRanges: [Range<Int>]?,
  ) -> [Injection] {
    var seen: Set<InjectableAttributeKey> = []
    return scanWindows(of: keptRanges, under: root, length: text.length).flatMap { window in
      let units = units(of: text, in: window)
      return InjectableAttributeCandidates.candidates(in: units).compactMap {
        inWindow -> Injection? in
        let candidate = InjectableAttributeCandidate(
          range: inWindow.range.shifted(by: window.lowerBound),
          kind: inWindow.kind,
        )
        guard let found = attribute(named: candidate, under: root) else { return nil }
        let written = String(decoding: units[inWindow.range], as: UTF16.self)
        let key = InjectableAttributeKey(
          tagNameStart: found.tagName.range.location,
          name: written.lowercased(),
        )
        guard seen.insert(key).inserted else { return nil }
        let tagRange = found.tagName.range.integerRange
        let tagName =
          tagRange.clamped(to: window) == tagRange
          ? units[tagRange.shifted(by: -window.lowerBound)]
          : Self.units(of: text, in: tagRange)[...]
        return injection(of: found.attribute, kind: candidate.kind, tagName: tagName, host: host)
      }
    }
  }

  /// All the text, or each kept range from the start of a tag it begins inside, so an
  /// attribute repeated there is still read as a repeat.
  private static func scanWindows(
    of keptRanges: [Range<Int>]?,
    under root: Node,
    length: Int,
  ) -> [Range<Int>] {
    guard let keptRanges else { return [0..<length] }
    var windows: [Range<Int>] = []
    for range in keptRanges {
      let start = min(range.lowerBound, tagStart(around: range.lowerBound, under: root))
      if let last = windows.last, start <= last.upperBound {
        windows[windows.count - 1] = last.lowerBound..<range.upperBound
      } else {
        windows.append(start..<range.upperBound)
      }
    }
    return windows
  }

  private static func tagStart(around offset: Int, under root: Node) -> Int {
    var node = root.descendant(in: NSRange(location: offset, length: 1).byteRange)
    while let current = node, !["start_tag", "self_closing_tag"].contains(current.nodeType) {
      node = current.parent
    }
    return node?.range.location ?? offset
  }

  /// Read from the caller's own `NSString`, so the text is bridged once a highlight.
  private static func units(of text: NSString, in range: Range<Int>) -> [UInt16] {
    var units = [UInt16](repeating: 0, count: range.count)
    units.withUnsafeMutableBufferPointer { buffer in
      guard let start = buffer.baseAddress else { return }
      text.getCharacters(start, range: NSRange(range))
    }
    return units
  }

  /// The attribute the scan named, and its element's tag name, looked up in the tree
  /// directly: a file's 40,000 such lookups took 42 ms in a release build.
  private static func attribute(
    named candidate: InjectableAttributeCandidate,
    under root: Node,
  ) -> (attribute: Node, tagName: Node)? {
    guard let node = root.descendant(in: NSRange(candidate.range).byteRange),
      node.nodeType == "attribute_name",
      node.range.integerRange == candidate.range,
      let attribute = node.parent, attribute.nodeType == "attribute",
      let tagName = attribute.parent?.namedChild(at: 0), tagName.nodeType == "tag_name"
    else { return nil }
    return (attribute, tagName)
  }

  /// An inline `style` as declarations, an event handler as JavaScript, on a tag
  /// the host injects them on.
  private static func injection(
    of attribute: Node,
    kind: InjectableAttributeCandidate.Kind,
    tagName: ArraySlice<UInt16>,
    host: MarkupHost,
  ) -> Injection? {
    guard host.injectsAttributes(ofTag: tagName),
      let value = expressionFreeValue(of: attribute)
    else { return nil }
    // A style's declarations parse only inside a rule.
    let (language, prefix, suffix): (HighlightLanguage, String, String) =
      switch kind {
      case .style: (.css, "a{", "}")
      case .handler: (.javaScript, "", "")
      }
    return Injection(
      range: value.range.integerRange,
      language: language,
      prefix: prefix,
      suffix: suffix,
      decodesCharacterReferences: true,
    )
  }

  /// The value, unless it holds a Svelte expression, which CSS breaks around.
  private static func expressionFreeValue(of attribute: Node) -> Node? {
    guard let value = attribute.attributeValue,
      !value.children.contains(where: { $0.nodeType == "expression" })
    else { return nil }
    return value
  }
}
