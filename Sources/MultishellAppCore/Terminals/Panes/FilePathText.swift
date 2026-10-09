import Foundation
import MultishellCore
import MultishellProcess

/// What a terminal receives for files dropped or pasted on it, never a newline.
public enum FilePathText {
  /// Quoted absolute paths for a shell, relative mentions for an agent, with
  /// a trailing space.
  static func droppedText(
    for urls: [URL],
    relativeTo directory: URL,
    mentionPrefix: String? = nil,
  ) -> String {
    let words =
      mentionPrefix.map { prefix in
        urls.filter(isTypable).map { prefix + escaping(path(of: $0, relativeTo: directory)) }
      } ?? quotedPaths(urls)
    guard !words.isEmpty else { return "" }
    return words.joined(separator: " ") + " "
  }

  /// What a paste of copied files types: each as a shell takes it, with no
  /// trailing space; `nil` where every file is left out.
  public static func pastedText(for urls: [URL]) -> String? {
    let paths = quotedPaths(urls)
    return paths.isEmpty ? nil : paths.joined(separator: " ")
  }

  private static func quotedPaths(_ urls: [URL]) -> [String] {
    urls.filter(isTypable).map { AnyShellQuoting.quote($0.standardizedFileURL.path) }
  }

  /// A path carrying a control character is left out rather than mangled: a
  /// newline would press Return, and no quoting reaches through a terminal.
  private static func isTypable(_ url: URL) -> Bool {
    !url.standardizedFileURL.path.holdsTerminalControl
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
    guard let below = url.pathComponents(under: directory), !below.isEmpty else {
      return url.standardizedFileURL.path
    }
    return below.joined(separator: "/")
  }
}
