import Foundation

/// An editor Open in Editor can hand a worktree to.
public struct EditorDescriptor: Identifiable, Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    /// A Mac application, found by bundle identifier, or through its command
    /// line shim when the application lookup has nothing.
    case application
    /// Runs inside a terminal, so it opens as a new tab in the worktree.
    case terminal
  }

  public let id: String
  public let name: String
  public let kind: Kind
  /// How the platform finds the application; the Mac's is the bundle id.
  public let bundleIdentifier: String?
  /// A command on the login shell's PATH that opens a directory when given
  /// its path: `code`, `subl`, `nvim`.
  public let command: String?

  public init(
    id: String, name: String, kind: Kind, bundleIdentifier: String? = nil, command: String? = nil
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.bundleIdentifier = bundleIdentifier
    self.command = command
  }
}
