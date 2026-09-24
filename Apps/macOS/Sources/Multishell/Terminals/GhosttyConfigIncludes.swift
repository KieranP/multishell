import Foundation

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
      guard seen.insert(url.resolvingSymlinksInPath().standardizedFileURL.path).inserted,
        let text = try? String(contentsOf: url, encoding: .utf8)
      else { continue }
      texts.append(text)
      queue += includes(in: text, from: url.deletingLastPathComponent(), home: home)
    }
    return texts
  }

  /// Swift reads `\r\n` as one character, so splitting on `\n` alone kept a
  /// CRLF file whole. Ghostty ends a line at either and nowhere else.
  static func lines(of text: String) -> [Substring] {
    text.split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r\n" }
  }

  /// A leading `?` makes a missing file quiet, which a missing one is here
  /// anyway; it goes before the quotes are taken off, `"?x"` naming a file.
  private static func includes(in text: String, from directory: URL, home: URL) -> [URL] {
    lines(of: text).compactMap { line in
      guard let equals = line.firstIndex(of: "="),
        line[..<equals].trimmingCharacters(in: .whitespaces).lowercased() == "config-file"
      else { return nil }
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
