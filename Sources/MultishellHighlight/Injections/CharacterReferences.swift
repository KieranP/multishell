/// HTML character references in an attribute's code, decoded so `&quot;` reads as
/// `"` and `&amp;&amp;` as `&&`, each decoded unit keeping its reference's offset.
enum CharacterReferences {
  /// HTML's names for ASCII punctuation, tab and newline, which change how code parses,
  /// and `&nbsp;`; the rest of its 2,000 names stay as written.
  private static let named: [String: Unicode.Scalar] = [
    "Tab": "\t", "NewLine": "\n", "excl": "!", "quot": "\"", "QUOT": "\"", "num": "#",
    "dollar": "$", "percnt": "%", "amp": "&", "AMP": "&", "apos": "'", "lpar": "(",
    "rpar": ")", "ast": "*", "midast": "*", "plus": "+", "comma": ",", "period": ".",
    "sol": "/", "colon": ":", "semi": ";", "lt": "<", "LT": "<", "equals": "=", "gt": ">",
    "GT": ">", "quest": "?", "commat": "@", "lsqb": "[", "lbrack": "[", "bsol": "\\",
    "rsqb": "]", "rbrack": "]", "Hat": "^", "lowbar": "_", "UnderBar": "_", "grave": "`",
    "DiacriticalGrave": "`", "lcub": "{", "lbrace": "{", "verbar": "|", "vert": "|",
    "VerticalLine": "|", "rcub": "}", "rbrace": "}", "nbsp": "\u{A0}",
  ]

  private static let longestName = named.keys.map(\.utf16.count).max() ?? 0

  /// The few HTML also reads with no `;` where no letter, digit or `=` follows:
  /// `a &amp&amp b`.
  private static let legacy: Set<String> = [
    "quot", "QUOT", "amp", "AMP", "lt", "LT", "gt", "GT", "nbsp",
  ]

  /// HTML reads `&#128;` to `&#159;` as windows-1252 would; the five it leaves
  /// undefined stand for themselves.
  private static let windows1252: [UInt32: Unicode.Scalar] = [
    0x80: "\u{20AC}", 0x82: "\u{201A}", 0x83: "\u{0192}", 0x84: "\u{201E}", 0x85: "\u{2026}",
    0x86: "\u{2020}", 0x87: "\u{2021}", 0x88: "\u{02C6}", 0x89: "\u{2030}", 0x8A: "\u{0160}",
    0x8B: "\u{2039}", 0x8C: "\u{0152}", 0x8E: "\u{017D}", 0x91: "\u{2018}", 0x92: "\u{2019}",
    0x93: "\u{201C}", 0x94: "\u{201D}", 0x95: "\u{2022}", 0x96: "\u{2013}", 0x97: "\u{2014}",
    0x98: "\u{02DC}", 0x99: "\u{2122}", 0x9A: "\u{0161}", 0x9B: "\u{203A}", 0x9C: "\u{0153}",
    0x9E: "\u{017E}", 0x9F: "\u{0178}",
  ]
  private static let replacement: Unicode.Scalar = "\u{FFFD}"
  private static let ampersand = UInt16(UInt8(ascii: "&"))
  private static let hash = UInt16(UInt8(ascii: "#"))
  private static let semicolon = UInt16(UInt8(ascii: ";"))
  private static let equals = UInt16(UInt8(ascii: "="))

  static func decoded(_ source: String) -> DecodedText {
    var offsets: [Int] = []
    offsets.reserveCapacity(source.utf16.count + 1)
    let text = decode(source) { start, count in
      offsets.append(contentsOf: repeatElement(start, count: count))
    }
    offsets.append(source.utf16.count)
    return DecodedText(text: text, sourceOffsets: offsets)
  }

  /// The decoded text alone, where no span is mapped back through it.
  static func decodedText(_ source: String) -> String {
    decode(source) { _, _ in }
  }

  /// `onDecodedRun` hears, for each run of decoded units, the source offset they came
  /// from and how many there are.
  private static func decode(
    _ source: String,
    onDecodedRun: (_ start: Int, _ count: Int) -> Void,
  ) -> String {
    let units = Array(source.utf16)
    var text: [UInt16] = []
    text.reserveCapacity(units.count)
    var index = 0
    while index < units.count {
      if units[index] == ampersand, let (scalar, end) = reference(in: units, at: index) {
        text.append(contentsOf: scalar.utf16)
        onDecodedRun(index, scalar.utf16.count)
        index = end
      } else {
        text.append(units[index])
        onDecodedRun(index, 1)
        index += 1
      }
    }
    return String(decoding: text, as: UTF16.self)
  }

  /// The character an `&` at `start` stands for and where its reference ends: a
  /// known name, or a decimal or hex number whose `;` HTML lets go.
  private static func reference(in units: [UInt16], at start: Int) -> (Unicode.Scalar, Int)? {
    let body = start + 1
    guard body < units.count else { return nil }
    if units[body] == hash { return number(in: units, at: body + 1) }
    // One past the longest name, as a longer run, a data URI's, can match none.
    let run = units[body...].prefix(longestName + 1).prefix { unit in
      ASCIIUnits.isLetter(unit) || ASCIIUnits.isDigit(unit)
    }
    guard !run.isEmpty, run.count <= longestName else { return nil }
    let end = body + run.count
    let name = String(decoding: units[body..<end], as: UTF16.self)
    guard let scalar = named[name] else { return nil }
    if end < units.count, units[end] == semicolon { return (scalar, end + 1) }
    let isFollowedByEquals = end < units.count && units[end] == equals
    return legacy.contains(name) && !isFollowedByEquals ? (scalar, end) : nil
  }

  private static func number(in units: [UInt16], at start: Int) -> (Unicode.Scalar, Int)? {
    let isHex =
      start < units.count && (units[start] | ASCIIUnits.lowercaseBit) == UInt16(UInt8(ascii: "x"))
    let first = isHex ? start + 1 : start
    let digits = units[min(first, units.count)...].prefix { unit in
      isHex ? isHexDigit(unit) : ASCIIUnits.isDigit(unit)
    }
    guard !digits.isEmpty else { return nil }
    let value = UInt32(String(decoding: digits, as: UTF16.self), radix: isHex ? 16 : 10)
    let end = first + digits.count
    return (scalar(for: value), end < units.count && units[end] == semicolon ? end + 1 : end)
  }

  /// As HTML reads a number: zero, a surrogate or one past Unicode is U+FFFD.
  private static func scalar(for value: UInt32?) -> Unicode.Scalar {
    guard let value, value != 0 else { return replacement }
    return windows1252[value] ?? Unicode.Scalar(value) ?? replacement
  }

  private static func isHexDigit(_ unit: UInt16) -> Bool {
    ASCIIUnits.isDigit(unit) || (0x61...0x66).contains(unit | ASCIIUnits.lowercaseBit)
  }
}
