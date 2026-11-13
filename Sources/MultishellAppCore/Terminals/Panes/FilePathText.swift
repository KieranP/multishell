import Foundation
import MultishellCore
import MultishellProcess

/// What a terminal receives for files dropped or pasted on it, never a newline.
public enum FilePathText {
  /// Quoted absolute paths for a shell, mentions for an agent relative to any
  /// directory given, one line; `nil` where every file is left out.
  public static func pastedText(
    for urls: [URL],
    relativeTo directory: URL?,
    mentionPrefix: String? = nil,
  ) -> String? {
    let words = words(for: urls, relativeTo: directory, mentionPrefix: mentionPrefix)
    return words.isEmpty ? nil : words.joined(separator: " ")
  }

  private static func words(
    for urls: [URL],
    relativeTo directory: URL?,
    mentionPrefix: String?,
  ) -> [String] {
    let typable = urls.filter(isTypable)
    guard let prefix = mentionPrefix else {
      return typable.map { AnyShellQuoting.quote($0.standardizedFileURL.path) }
    }
    return typable.map { url in
      let path = path(of: url, relativeTo: directory)
      guard isMentionable(path) else { return AnyShellQuoting.quote(url.standardizedFileURL.path) }
      return prefix + escaping(path)
    }
  }

  /// Claude Code's mention ends at any Unicode space and escapes only an ASCII
  /// one, so a screenshot's narrow no-break space or a backslash cut it short.
  private static func isMentionable(_ path: String) -> Bool {
    !path.unicodeScalars.contains { scalar in
      scalar == "\\" || (scalar != " " && scalar.properties.isWhitespace)
    }
  }

  /// A path carrying a control character is left out rather than mangled: a
  /// newline would press Return, and no quoting reaches through a terminal.
  private static func isTypable(_ url: URL) -> Bool {
    !url.standardizedFileURL.path.holdsTerminalControl
  }

  /// A space is escaped, not quoted: a mention ends at whitespace and a quote lands as text.
  /// By scalar, as a space before a combining mark is one Character a search misses.
  private static func escaping(_ path: String) -> String {
    var escaped = ""
    for scalar in path.unicodeScalars {
      if scalar == " " { escaped.unicodeScalars.append("\\") }
      escaped.unicodeScalars.append(scalar)
    }
    return escaped
  }

  /// Relative inside the directory, absolute otherwise. Both sides as spelled
  /// first, then resolved, an agent's getcwd naming a symlink's target.
  private static func path(of url: URL, relativeTo directory: URL?) -> String {
    guard let directory,
      let below = url.pathComponents(under: directory)
        ?? url.resolvingSymlinksInPath().pathComponents(
          under: directory.resolvingSymlinksInPath()
        ),
      !below.isEmpty
    else {
      return url.standardizedFileURL.path
    }
    return below.joined(separator: "/")
  }
}
