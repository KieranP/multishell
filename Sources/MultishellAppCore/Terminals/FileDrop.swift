import Foundation
import MultishellCore

/// What a terminal receives when files are dropped: quoted absolute paths for
/// a shell, relative mentions for an agent. A trailing space, never a newline.
public enum FileDrop {
  public static func text(
    for urls: [URL], relativeTo directory: URL, mentionPrefix: String? = nil
  ) -> String {
    let words = urls.filter { isTypable($0) }.map { url in
      guard let mentionPrefix else { return ShellQuoting.quote(url.standardizedFileURL.path) }
      return mentionPrefix + escaping(path(of: url, relativeTo: directory))
    }
    guard !words.isEmpty else { return "" }
    return words.joined(separator: " ") + " "
  }

  /// A path carrying a control character is left out rather than mangled: a
  /// newline would press Return, and no quoting reaches through a terminal.
  private static func isTypable(_ url: URL) -> Bool {
    !url.standardizedFileURL.path.unicodeScalars.contains {
      $0.value < 0x20 || $0.value == 0x7f || (0x80...0x9f).contains($0.value)
    }
  }

  /// A mention ends at whitespace, so a space is escaped rather than quoted,
  /// a quote landing in the prompt as a character.
  private static func escaping(_ path: String) -> String {
    path
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: " ", with: "\\ ")
  }

  /// Relative inside the session's directory, absolute otherwise. Both sides
  /// standardized and neither resolved, as the session recorded its own.
  private static func path(of url: URL, relativeTo directory: URL) -> String {
    let path = url.standardizedFileURL.path
    let base = directory.standardizedFileURL.path
    let root = base.hasSuffix("/") ? base : base + "/"
    guard path.hasPrefix(root), path.count > root.count else { return path }
    return String(path.dropFirst(root.count))
  }
}
