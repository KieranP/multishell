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
    var marked: [UInt8] = []
    marked.reserveCapacity(bytes.count + 32)
    var index = 0
    var inString = false
    var escaped = false
    while index < bytes.count {
      let byte = bytes[index]
      if inString {
        marked.append(byte)
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
        marked.append(byte)
        index += 1
      } else if byte == UInt8(ascii: "-") || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
      {
        var end = index
        while end < bytes.count, numberBytes.contains(bytes[end]) { end += 1 }
        let run = bytes[index..<end]
        // Only a literal JSON allows; anything else stays for the parser to refuse.
        if isJSONNumber(run) {
          marked.append(UInt8(ascii: "\""))
          marked.append(contentsOf: mark.utf8)
          marked.append(contentsOf: run)
          marked.append(UInt8(ascii: "\""))
        } else {
          marked.append(contentsOf: run)
        }
        index = end
      } else {
        marked.append(byte)
        index += 1
      }
    }
    return String(decoding: marked, as: UTF8.self)
  }

  /// `-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?`, RFC 8259's grammar.
  private static func isJSONNumber(_ run: ArraySlice<UInt8>) -> Bool {
    var index = run.startIndex
    func digits() -> Int {
      let start = index
      while index < run.endIndex, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(run[index]) {
        index += 1
      }
      return index - start
    }
    if index < run.endIndex, run[index] == UInt8(ascii: "-") { index += 1 }
    guard index < run.endIndex else { return false }
    if run[index] == UInt8(ascii: "0") {
      index += 1
    } else if digits() == 0 {
      return false
    }
    if index < run.endIndex, run[index] == UInt8(ascii: ".") {
      index += 1
      guard digits() > 0 else { return false }
    }
    if index < run.endIndex, run[index] == UInt8(ascii: "e") || run[index] == UInt8(ascii: "E") {
      index += 1
      if index < run.endIndex, run[index] == UInt8(ascii: "+") || run[index] == UInt8(ascii: "-") {
        index += 1
      }
      guard digits() > 0 else { return false }
    }
    return index == run.endIndex
  }

  static func unmarking(_ rendered: String) -> String {
    rendered.replacingOccurrences(
      of: "\"\\\\u0001\(token)([-+.0-9eE]+)\"",
      with: "$1",
      options: .regularExpression,
    )
  }
}
