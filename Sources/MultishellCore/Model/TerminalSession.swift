import Foundation

/// One terminal tab. Unlike projects and worktrees this has no natural key,
/// so it carries a generated id.
///
/// This describes what a terminal *should* be, not a running process. The
/// process lives behind `TerminalHost` in the GUI layer.
public struct TerminalSession: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public var worktreeID: Worktree.ID
  public var workingDirectory: URL
  public var title: String
  /// `nil` runs the user's login shell.
  public var command: [String]?

  public init(
    id: UUID = UUID(),
    worktreeID: Worktree.ID,
    workingDirectory: URL,
    title: String,
    command: [String]? = nil
  ) {
    self.id = id
    self.worktreeID = worktreeID
    self.workingDirectory = workingDirectory.standardizedFileURL
    self.title = title
    self.command = command
  }
}
