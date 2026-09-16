import Foundation

/// A number in a settings file, kept as the user spelled it: a string
/// carrying the literal behind a marker across the parse; see agents.md.
enum NumberLiteral {
  // U+0001 and a token this process alone knows, so a string of the user's
  // cannot be taken for a marked number on the way back out.
  private static let token = UUID().uuidString.prefix(8).lowercased()
  private static let mark = "\\u0001" + token
  private static let numberBytes = Set("0123456789+-.eE".utf8)

  static func marking(_ json: String) -> String {
    let bytes = Array(json.utf8)
    var out: [UInt8] = []
    out.reserveCapacity(bytes.count + 32)
    var index = 0
    var inString = false
    var escaped = false
    while index < bytes.count {
      let byte = bytes[index]
      if inString {
        out.append(byte)
        if escaped {
          escaped = false
        } else if byte == UInt8(ascii: "\\") {
          escaped = true
        } else if byte == UInt8(ascii: "\"") {
          inString = false
        }
        index += 1
      } else if byte == UInt8(ascii: "\"") {
        inString = true
        out.append(byte)
        index += 1
      } else if byte == UInt8(ascii: "-") || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
      {
        var end = index
        while end < bytes.count, numberBytes.contains(bytes[end]) { end += 1 }
        let run = bytes[index..<end]
        // Only a literal JSON allows; anything else stays for the parser to refuse.
        if isJSONNumber(run) {
          out.append(UInt8(ascii: "\""))
          out.append(contentsOf: mark.utf8)
          out.append(contentsOf: run)
          out.append(UInt8(ascii: "\""))
        } else {
          out.append(contentsOf: run)
        }
        index = end
      } else {
        out.append(byte)
        index += 1
      }
    }
    return String(decoding: out, as: UTF8.self)
  }

  /// `-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?`, RFC 8259's grammar.
  private static func isJSONNumber(_ run: ArraySlice<UInt8>) -> Bool {
    var i = run.startIndex
    func digits() -> Int {
      let start = i
      while i < run.endIndex, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(run[i]) { i += 1 }
      return i - start
    }
    if i < run.endIndex, run[i] == UInt8(ascii: "-") { i += 1 }
    guard i < run.endIndex else { return false }
    if run[i] == UInt8(ascii: "0") {
      i += 1
    } else if digits() == 0 {
      return false
    }
    if i < run.endIndex, run[i] == UInt8(ascii: ".") {
      i += 1
      guard digits() > 0 else { return false }
    }
    if i < run.endIndex, run[i] == UInt8(ascii: "e") || run[i] == UInt8(ascii: "E") {
      i += 1
      if i < run.endIndex, run[i] == UInt8(ascii: "+") || run[i] == UInt8(ascii: "-") { i += 1 }
      guard digits() > 0 else { return false }
    }
    return i == run.endIndex
  }

  static func unmarking(_ rendered: String) -> String {
    rendered.replacingOccurrences(
      of: "\"\\\\u0001\(token)([-+.0-9eE]+)\"", with: "$1", options: .regularExpression)
  }
}
