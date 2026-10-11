import Foundation

/// What the command line names a project or worktree by: short, the same
/// every run, and no path, though the model keys both by theirs; agents.md.
public enum ControlID {
  public static func project(_ id: Project.ID) -> String { "p-" + digits(of: id) }
  public static func worktree(_ id: Worktree.ID) -> String { "w-" + digits(of: id) }

  /// Spelled as a project's id, checked before the app is asked.
  public static func isProject(_ text: String) -> Bool { isSpelled(text, prefix: "p-") }
  public static func isWorktree(_ text: String) -> Bool { isSpelled(text, prefix: "w-") }

  private static func digits(of path: String) -> String {
    String(format: "%08x", path.stableHash)
  }

  private static func isSpelled(_ text: String, prefix: String) -> Bool {
    text.hasPrefix(prefix) && text.count == prefix.count + 8
      && text.dropFirst(prefix.count).allSatisfy { "0123456789abcdef".contains($0) }
  }
}
