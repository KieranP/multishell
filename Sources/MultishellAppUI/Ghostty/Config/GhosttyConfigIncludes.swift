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
      let directory = url.deletingLastPathComponent()
      texts.append(GhosttyConfigRelativePaths.resolved(in: text, from: directory))
      queue += includes(in: text, from: directory, home: home)
    }
    return texts
  }

  /// A missing file, optional or not, is skipped as any is here.
  private static func includes(in text: String, from directory: URL, home: URL) -> [URL] {
    GhosttyConfigLine.lines(of: text).compactMap { line in
      guard GhosttyConfigLine.key(of: line) == "config-file" else { return nil }
      return GhosttyConfigPathValue(of: line)?.url(from: directory, home: home)
    }
  }
}
