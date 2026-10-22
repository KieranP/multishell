/// A Svelte file as its grammar is given it, each `>` and bare `&` in text content a space.
/// The grammar's text refuses both, and past a few lines its recovery leaves the rest one error.
enum SvelteGrammarInput {
  private static let lessThan = UInt16(UInt8(ascii: "<"))
  private static let greaterThan = UInt16(UInt8(ascii: ">"))
  private static let ampersand = UInt16(UInt8(ascii: "&"))
  private static let openBrace = UInt16(UInt8(ascii: "{"))
  private static let closeBrace = UInt16(UInt8(ascii: "}"))
  private static let slash = UInt16(UInt8(ascii: "/"))
  private static let bang = UInt16(UInt8(ascii: "!"))
  private static let star = UInt16(UInt8(ascii: "*"))
  private static let hash = UInt16(UInt8(ascii: "#"))
  private static let dollar = UInt16(UInt8(ascii: "$"))
  private static let backtick = UInt16(UInt8(ascii: "`"))
  private static let lowercaseX = UInt16(UInt8(ascii: "x"))
  private static let space = UInt16(UInt8(ascii: " "))
  private static let quotes = Set("\"'".utf16)
  private static let lineBreaks = Set("\n\r".utf16)
  private static let commentOpening = Array("<!--".utf16)
  private static let commentClosing = Array("-->".utf16)
  private static let blockCommentClosing = Array("*/".utf16)
  private static let rawTextTags = [Array("script".utf16), Array("style".utf16)]

  /// The same length in UTF-16, so every node's range is the source's.
  static func text(from source: String) -> String {
    var units = Array(source.utf16)
    var blanksAny = false
    var index = 0
    while index < units.count {
      switch units[index] {
      case lessThan:
        index = markupEnd(from: index, in: units)

      case openBrace:
        index = expressionEnd(from: index, in: units)

      case greaterThan,
        ampersand where !startsCharacterReference(at: index, in: units):
        units[index] = space
        blanksAny = true
        index += 1

      default:
        index += 1
      }
    }
    return blanksAny ? String(decoding: units, as: UTF16.self) : source
  }

  /// Past a comment, a doctype or an end tag, or a start tag and, for `script` or `style`
  /// in lowercase, its body; a `<` before no tag name is text, as the grammar reads it.
  private static func markupEnd(from start: Int, in units: [UInt16]) -> Int {
    if units[start...].starts(with: commentOpening) {
      return end(of: commentClosing, from: start + commentOpening.count, in: units)
    }
    let next = start + 1
    guard next < units.count else { return next }
    if units[next] == slash || units[next] == bang {
      return end(of: [greaterThan], from: next, in: units)
    }
    guard ASCIIUnits.isLetter(units[next]) else { return next }
    let tagEnd = startTagEnd(from: next, in: units)
    let nameEnd =
      units[next..<tagEnd].firstIndex { unit in
        ASCIIUnits.whitespace.contains(unit) || unit == slash || unit == greaterThan
      } ?? tagEnd
    guard
      let rawTextTag = rawTextTags.first(where: { units[next..<nameEnd].elementsEqual($0) }),
      units[tagEnd - 1] == greaterThan, units[tagEnd - 2] != slash
    else { return tagEnd }
    return rawTextEnd(named: rawTextTag, from: tagEnd, in: units)
  }

  private static func startTagEnd(from start: Int, in units: [UInt16]) -> Int {
    var index = start
    while index < units.count {
      let unit = units[index]
      if unit == greaterThan { return index + 1 }
      if unit == openBrace {
        index = expressionEnd(from: index, in: units)
      } else if quotes.contains(unit) {
        index = quotedValueEnd(from: index, in: units)
      } else {
        index += 1
      }
    }
    return index
  }

  private static func quotedValueEnd(from start: Int, in units: [UInt16]) -> Int {
    var index = start + 1
    while index < units.count {
      if units[index] == units[start] { return index + 1 }
      index = units[index] == openBrace ? expressionEnd(from: index, in: units) : index + 1
    }
    return index
  }

  /// At the `<` of the closing tag, matched in any case as the grammar's scanner matches it.
  private static func rawTextEnd(
    named name: [UInt16],
    from start: Int,
    in units: [UInt16],
  ) -> Int {
    var index = start
    while let opening = units[index...].firstIndex(of: lessThan) {
      let nameStart = opening + 2
      if nameStart + name.count <= units.count, units[opening + 1] == slash,
        matchesIgnoringCase(units[nameStart..<(nameStart + name.count)], name)
      {
        return opening
      }
      index = opening + 1
    }
    return units.count
  }

  /// Past the `}` closing the `{` at `start`, skipping what JavaScript's strings and
  /// comments hold, as the grammar's scanner ends a Svelte expression. Its `\` escapes
  /// nothing there, so `{/\}/}` ends at the first `}`.
  private static func expressionEnd(from start: Int, in units: [UInt16]) -> Int {
    var depth = 0
    var index = start + 1
    while index < units.count {
      let unit = units[index]
      switch unit {
      case closeBrace:
        if depth == 0 { return index + 1 }
        depth -= 1
        index += 1

      case openBrace:
        depth += 1
        index += 1

      case backtick:
        index = templateEnd(from: index, in: units)

      case slash where index + 1 < units.count && units[index + 1] == star:
        index = end(of: blockCommentClosing, from: index + 2, in: units)

      case slash where index + 1 < units.count && units[index + 1] == slash:
        index = (units[index...].firstIndex { lineBreaks.contains($0) } ?? units.count) + 1

      default:
        index = quotes.contains(unit) ? stringEnd(from: index, in: units) : index + 1
      }
    }
    return units.count
  }

  private static func stringEnd(from start: Int, in units: [UInt16]) -> Int {
    var index = start + 1
    while index < units.count {
      if units[index] == units[start] { return index + 1 }
      index += units[index] == ASCIIUnits.backslash ? 2 : 1
    }
    return units.count
  }

  private static func templateEnd(from start: Int, in units: [UInt16]) -> Int {
    var index = start + 1
    while index < units.count {
      switch units[index] {
      case backtick:
        return index + 1

      case ASCIIUnits.backslash:
        index += 2

      case dollar where index + 1 < units.count && units[index + 1] == openBrace:
        index = substitutionEnd(from: index + 1, in: units)

      default:
        index += 1
      }
    }
    return units.count
  }

  /// Past the `}` closing a template's `${`, read as the grammar's scanner reads it:
  /// a `\` escapes the unit after it, and a comment hides no brace.
  private static func substitutionEnd(from start: Int, in units: [UInt16]) -> Int {
    var depth = 0
    var index = start + 1
    while index < units.count {
      let unit = units[index]
      switch unit {
      case closeBrace:
        if depth == 0 { return index + 1 }
        depth -= 1
        index += 1

      case openBrace:
        depth += 1
        index += 1

      case ASCIIUnits.backslash:
        index += 2

      case backtick:
        index = templateEnd(from: index, in: units)

      default:
        index = quotes.contains(unit) ? stringEnd(from: index, in: units) : index + 1
      }
    }
    return units.count
  }

  /// `&` and a letter, `&#` and a digit or `&#x` and a hex digit, as the grammar's entity begins.
  private static func startsCharacterReference(at index: Int, in units: [UInt16]) -> Bool {
    guard index + 1 < units.count else { return false }
    let next = units[index + 1]
    if ASCIIUnits.isLetter(next) { return true }
    guard next == hash, index + 2 < units.count else { return false }
    let afterHash = units[index + 2]
    if ASCIIUnits.isDigit(afterHash) { return true }
    guard afterHash | ASCIIUnits.lowercaseBit == lowercaseX, index + 3 < units.count else {
      return false
    }
    return isHexDigit(units[index + 3])
  }

  private static func isHexDigit(_ unit: UInt16) -> Bool {
    ASCIIUnits.isDigit(unit) || (0x61...0x66).contains(unit | ASCIIUnits.lowercaseBit)
  }

  private static func matchesIgnoringCase(
    _ name: ArraySlice<UInt16>,
    _ lowercased: [UInt16],
  )
    -> Bool
  {
    name.count == lowercased.count
      && zip(name, lowercased).allSatisfy { $0 | ASCIIUnits.lowercaseBit == $1 }
  }

  private static func end(of closing: [UInt16], from start: Int, in units: [UInt16]) -> Int {
    var index = start
    while index + closing.count <= units.count {
      if units[index..<(index + closing.count)].elementsEqual(closing) {
        return index + closing.count
      }
      index += 1
    }
    return units.count
  }
}
