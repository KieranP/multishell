import Foundation
import MultishellCore

/// The user's Ghostty files and the files they include, in Ghostty's order,
/// followed here since libghostty is handed one file; see terminals/engine-and-config.md.
enum GhosttyConfigIncludes {
  /// Each file's text, an include after the whole file that names it and a
  /// file already read skipped, which is what ends a cycle.
  static func contents(following roots: [URL], home: URL) -> [String] {
    var queue = roots
    var seen: Set<String> = []
    var texts: [String] = []
    var next = 0
    while next < queue.count {
      let url = queue[next]
      next += 1
      // Decoded leniently: Ghostty reads lines as bytes, so a Latin-1 comment cost it nothing.
      guard seen.insert(url.comparablePath).inserted, let data = try? Data(contentsOf: url)
      else { continue }
      // Ghostty skips a byte order mark; kept, it joins the first line's key.
      let text = String(String(decoding: data, as: UTF8.self).trimmingPrefix("\u{FEFF}"))
      texts.append(text)
      queue += includes(in: text, from: url.deletingLastPathComponent(), home: home)
    }
    return texts
  }

  /// A `?` quiets a missing file, as any is here. Ghostty unquotes the line before
  /// its path parser reads the `?` and unquotes again, so `"?x"` and `?"x"` name x.
  private static func includes(in text: String, from directory: URL, home: URL) -> [URL] {
    GhosttyConfigLine.lines(of: text).compactMap { line in
      guard GhosttyConfigLine.key(of: line) == "config-file",
        let equals = line.unicodeScalars.firstIndex(of: "=")
      else {
        return nil
      }
      let afterEquals = line[line.unicodeScalars.index(after: equals)...]
      var value = unquoted(afterEquals.trimmingCharacters(in: .whitespaces))
      value = unquoted(value.removingPrefix("?") ?? value)
      guard !value.isEmpty else { return nil }
      if let inHome = value.removingPrefix("~/") { return home.appendingPathComponent(inHome) }
      if value.utf8.first == UInt8(ascii: "/") { return URL(fileURLWithPath: value) }
      return directory.appendingPathComponent(value)
    }
  }

  /// By byte, as each check above: a combining mark after a quote joins it into one `Character`.
  private static func unquoted(_ value: String) -> String {
    let quote = UInt8(ascii: "\"")
    let bytes = value.utf8
    guard bytes.count >= 2, bytes.first == quote, bytes.last == quote else { return value }
    return String(Substring(bytes.dropFirst().dropLast()))
  }
}
