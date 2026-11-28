import Foundation
import MultishellCore

/// A path a line sets, read as Ghostty's path parser reads it.
struct GhosttyConfigPathValue {
  /// A `?` quiets a missing file.
  let isOptional: Bool
  let path: String

  /// Whether Ghostty reads it against the directory of the file naming it.
  var isRelative: Bool {
    !path.hasPrefix("~/") && path.utf8.first != UInt8(ascii: "/")
  }

  /// A `?` and quotes either side of it: Ghostty unquotes the line before its
  /// path parser reads the `?` and unquotes again, so `"?x"` and `?"x"` name x.
  init?(of line: Substring) {
    guard let equals = line.unicodeScalars.firstIndex(of: "=") else { return nil }
    let afterEquals = line[line.unicodeScalars.index(after: equals)...]
    let value = Self.unquoted(afterEquals.trimmingCharacters(in: .whitespaces))
    let afterMark = value.removingPrefix("?")
    path = Self.unquoted(afterMark ?? value)
    isOptional = afterMark != nil
    guard !path.isEmpty else { return nil }
  }

  /// By byte, as the checks here: a combining mark after a quote joins it into one `Character`.
  private static func unquoted(_ value: String) -> String {
    let quote = UInt8(ascii: "\"")
    let bytes = value.utf8
    guard bytes.count >= 2, bytes.first == quote, bytes.last == quote else { return value }
    return String(Substring(bytes.dropFirst().dropLast()))
  }

  func url(from directory: URL, home: URL) -> URL {
    if let inHome = path.removingPrefix("~/") { return home.appendingPathComponent(inHome) }
    if !isRelative { return URL(fileURLWithPath: path) }
    return directory.appendingPathComponent(path)
  }
}
