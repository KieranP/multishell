/// A Svelte block head's units, comments blanked, with the brackets that quotes and regexes
/// hide; a quote left open, as by a regex read as division, rescans with quotes as text.
struct ScannedBlockHead {
  /// Where a regex scan stands at a unit, outside an escape: what follows is fixed by it.
  private struct RegexScanPoint: Hashable {
    let index: Int
    let isInClass: Bool
  }

  private static let openingBrackets = Set("([{".utf16)
  private static let openSquareBracket = UInt16(UInt8(ascii: "["))
  private static let closeSquareBracket = UInt16(UInt8(ascii: "]"))
  /// JavaScript's line ends, which close a `//` comment and stop a regex.
  private static let lineEnds = Set("\n\r\u{2028}\u{2029}".utf16)

  private(set) var units: [UInt16]
  private(set) var bracketDepths: [Int?]
  private(set) var openingParenthesisByClosing: [Int?]

  init(_ head: String) {
    let units = Array(head.utf16)
    var scanned = Self(unscanned: units)
    if !scanned.scan(readsQuotes: true) {
      scanned = Self(unscanned: units)
      scanned.scan(readsQuotes: false)
    }
    self = scanned
  }

  private init(unscanned units: [UInt16]) {
    self.units = units
    // A unit in a string or a regex keeps no depth.
    bracketDepths = Array(repeating: nil, count: units.count)
    openingParenthesisByClosing = Array(repeating: nil, count: units.count)
  }

  /// Past the regex's closing `/`, not one escaped or in a `[…]` class, and its flags;
  /// `nil` where the line ends first. `unclosed`: see Docs/design/files.md.
  private static func regexEnd(
    in text: [UInt16],
    at start: Int,
    unclosed: inout Set<RegexScanPoint>,
  ) -> Int? {
    var isEscaped = false
    var isInClass = false
    var passed: [RegexScanPoint] = []
    for index in (start + 1)..<text.count {
      let unit = text[index]
      if !isEscaped {
        let point = RegexScanPoint(index: index, isInClass: isInClass)
        if unclosed.contains(point) { break }
        passed.append(point)
      }
      if isEscaped {
        isEscaped = false
      } else if unit == ASCIIUnits.backslash {
        isEscaped = true
      } else if lineEnds.contains(unit) {
        break
      } else if unit == openSquareBracket || unit == closeSquareBracket {
        isInClass = unit == openSquareBracket
      } else if unit == ASCIIUnits.slash, !isInClass {
        return text[(index + 1)...].firstIndex { !JavaScriptUnits.isWordUnit($0) } ?? text.count
      }
    }
    unclosed.formUnion(passed)
    return nil
  }

  /// Where a `//` or `/*` comment starting at `index` ends; `nil` if none starts.
  private static func commentEnd(in text: [UInt16], at index: Int) -> Int? {
    guard text[index] == ASCIIUnits.slash, index + 1 < text.count else { return nil }
    let body = index + 2
    switch text[index + 1] {
    case ASCIIUnits.slash:
      return text[body...].firstIndex(where: lineEnds.contains) ?? text.count

    case ASCIIUnits.star:
      return text.index(past: ASCIIUnits.blockCommentClosing, from: body)

    default:
      return nil
    }
  }

  /// Whether every quote closed; with quotes unread none is left open.
  @discardableResult
  private mutating func scan(readsQuotes: Bool) -> Bool {
    let text = units
    var depth = 0
    var openBrackets: [Int] = []
    var string = OpenString()
    var previous: Int?
    var unclosedRegexes: Set<RegexScanPoint> = []
    var index = 0
    while index < text.count {
      let unit = text[index]
      if string.isOpen || (readsQuotes && JavaScriptUnits.quotes.contains(unit)) {
        string.read(unit)
        previous = index
        index += 1
        continue
      }
      if let end = Self.commentEnd(in: text, at: index) {
        for blank in index..<end {
          units[blank] = ASCIIUnits.space
          bracketDepths[blank] = depth
        }
        index = end
        continue
      }
      // A regex hides what it holds as a string does, its `//` being no comment.
      if unit == ASCIIUnits.slash, startsRegex(after: previous),
        let end = Self.regexEnd(in: text, at: index, unclosed: &unclosedRegexes)
      {
        previous = end - 1
        index = end
        continue
      }
      if JavaScriptUnits.closingBrackets.contains(unit) {
        depth = max(depth - 1, 0)
        if let open = openBrackets.popLast(), unit == JavaScriptUnits.closeParenthesis,
          text[open] == JavaScriptUnits.openParenthesis
        {
          openingParenthesisByClosing[index] = open
        }
      }
      bracketDepths[index] = depth
      if Self.openingBrackets.contains(unit) {
        depth += 1
        openBrackets.append(index)
      }
      if !ASCIIUnits.whitespace.contains(unit) { previous = index }
      index += 1
    }
    return !string.isOpen
  }

  /// A `/` divides where an expression has just ended, `a!/2` and `{}/2` too, and
  /// starts a regex anywhere else, `typeof /x/` included.
  private func startsRegex(after previous: Int?) -> Bool {
    guard let previous else { return true }
    return !endsExpression(at: previous)
  }
}
