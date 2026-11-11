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
      guard GhosttyConfigLine.key(of: line) == "config-file", let equals = line.firstIndex(of: "=")
      else {
        return nil
      }
      var value = unquoted(line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces))
      if value.hasPrefix("?") { value.removeFirst() }
      value = unquoted(value)
      guard !value.isEmpty else { return nil }
      if value.hasPrefix("~/") { return home.appendingPathComponent(String(value.dropFirst(2))) }
      if value.hasPrefix("/") { return URL(fileURLWithPath: value) }
      return directory.appendingPathComponent(value)
    }
  }

  private static func unquoted(_ value: String) -> String {
    guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else { return value }
    return String(value.dropFirst().dropLast())
  }
}
