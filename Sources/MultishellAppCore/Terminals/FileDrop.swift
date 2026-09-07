import Foundation
import MultishellCore

/// What a terminal receives when files are dropped on it.
///
/// A shell gets what every terminal emulator gives it: absolute paths,
/// quoted the way the shell will unquote them. An agent that names files
/// with a prefix gets that instead, against paths relative to the session's
/// own directory, which is what its mentions resolve against and what its
/// user would have typed. Either way a trailing space, so the next drop or
/// word stands apart, and never a newline: a drop leaves something to read
/// before Return is pressed, it does not submit or run.
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
  /// newline in a file name would press Return at the prompt, an escape
  /// would be read as a sequence, and a drag asked for neither. Both are
  /// legal in a file name and no quoting reaches through a terminal to undo
  /// them. The rest of the drop still goes in; that file is still there to
  /// be typed by hand.
  private static func isTypable(_ url: URL) -> Bool {
    !url.standardizedFileURL.path.unicodeScalars.contains {
      $0.value < 0x20 || $0.value == 0x7f || (0x80...0x9f).contains($0.value)
    }
  }

  /// A mention ends at whitespace, so a space in the path is escaped rather
  /// than quoted: the backslash is the form a shell and an agent's prompt
  /// both take, where a quote would land in the prompt as a character.
  private static func escaping(_ path: String) -> String {
    path
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: " ", with: "\\ ")
  }

  /// Relative when the file is inside the session's directory, absolute
  /// otherwise, including the directory itself: an empty mention names
  /// nothing. Both sides are standardized and neither is resolved, which is
  /// how the session recorded its own directory.
  private static func path(of url: URL, relativeTo directory: URL) -> String {
    let path = url.standardizedFileURL.path
    let base = directory.standardizedFileURL.path
    let root = base.hasSuffix("/") ? base : base + "/"
    guard path.hasPrefix(root), path.count > root.count else { return path }
    return String(path.dropFirst(root.count))
  }
}
