import Foundation

/// What a terminal should be, not a running process, which lives behind
/// `TerminalHost`. No natural key, so it carries a generated id.
public struct TerminalSession: Identifiable, Codable, Hashable, Sendable {
  /// `shellOverride` is left out on purpose; see its doc comment.
  enum CodingKeys: String, CodingKey {
    case id, worktreeID, workingDirectory, title, command, agentID
  }

  public let id: UUID
  public internal(set) var worktreeID: Worktree.ID
  public internal(set) var workingDirectory: URL
  public internal(set) var title: String
  /// `nil` runs the user's login shell.
  public var command: [String]?
  /// The agent this tab was opened for. The command line is built when the
  /// shell starts, so a saved tab resumes and a new install applies.
  public internal(set) var agentID: String?
  /// The shell to run when `command` is nil. Runtime only, never saved: a
  /// relaunched tab reads the setting again.
  public var shellOverride: String?

  /// A plain shell's title is saved empty and put in words here, or a tab
  /// saved under one language kept that language's word under the next.
  public var displayTitle: String { title.isEmpty ? t("tab.shell") : title }

  /// What the session runs as: the chosen shell, else `$SHELL`.
  public var shellPath: String {
    shellOverride ?? ShellChoice.loginShellPath()
  }

  init(
    worktreeID: Worktree.ID,
    workingDirectory: URL,
    title: String,
    id: UUID = UUID(),
    command: [String]? = nil,
    agentID: String? = nil,
    shellOverride: String? = nil,
  ) {
    self.id = id
    self.worktreeID = worktreeID
    self.workingDirectory = workingDirectory.standardizedFileURL
    self.title = title
    self.command = command
    self.agentID = agentID
    self.shellOverride = shellOverride
  }
}
