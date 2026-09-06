import MultishellCore

/// The one-time question about a repository's `.multishell.json`: its hooks
/// run code on this machine on the say of whoever committed the file, so
/// they are shown and take effect only once the user has said yes. Asked
/// again when the text changes; a no is remembered the same way.
public struct PendingSharedHooksTrust: Identifiable, Equatable, Sendable {
  public let projectID: Project.ID
  public let projectName: String
  /// The text the decision is about, `SharedProjectSettings.hooksText`.
  public let hooks: String

  public init(projectID: Project.ID, projectName: String, hooks: String) {
    self.projectID = projectID
    self.projectName = projectName
    self.hooks = hooks
  }

  public var id: String { projectID }

  public var title: String {
    "Run the hooks in \(projectName)'s \(SharedProjectSettings.fileName)?"
  }

  public var message: String {
    "The repository ships these hooks. They would run through your shell when a worktree is created or removed, where your own hook for that stage is blank.\n\n\(hooks)"
  }

  public var trustLabel: String { "Run Hooks" }
  public var declineLabel: String { "Ignore Hooks" }
}
