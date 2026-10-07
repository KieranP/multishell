import Foundation
import MultishellCore

/// The user's Ghostty files and the files they include, in Ghostty's order,
/// followed here since libghostty is handed one file; see terminals.md.
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
      guard seen.insert(url.comparablePath).inserted,
        let text = try? String(contentsOf: url, encoding: .utf8)
      else { continue }
      texts.append(text)
      queue += includes(in: text, from: url.deletingLastPathComponent(), home: home)
    }
    return texts
  }

  /// A leading `?` makes a missing file quiet, which a missing one is here
  /// anyway; it goes before the quotes are taken off, `"?x"` naming a file.
  private static func includes(in text: String, from directory: URL, home: URL) -> [URL] {
    GhosttyConfigLine.lines(of: text).compactMap { line in
      guard GhosttyConfigLine.key(of: line) == "config-file", let equals = line.firstIndex(of: "=")
      else {
        return nil
      }
      var value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
      if value.hasPrefix("?") { value.removeFirst() }
      if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
        value = String(value.dropFirst().dropLast())
      }
      guard !value.isEmpty else { return nil }
      if value.hasPrefix("~/") { return home.appendingPathComponent(String(value.dropFirst(2))) }
      if value.hasPrefix("/") { return URL(fileURLWithPath: value) }
      return directory.appendingPathComponent(value)
    }
  }
}
