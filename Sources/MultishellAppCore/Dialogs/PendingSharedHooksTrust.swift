import MultishellCore

/// The one-time question about a repository's `.multishell.json`: its hooks
/// run code on this machine on the say of whoever committed the file, so
/// they are shown and take effect only once the user has said yes. A file
/// nobody has answered about is asked about; a yes and a no are both
/// remembered against the sha256 of the file they were given for, so
/// switching between branches that ship different hooks asks each once
/// rather than each time.
public struct PendingSharedHooksTrust: Identifiable, Equatable, Sendable {
  public let projectID: Project.ID
  public let projectName: String
  /// The hooks as they are shown, `SharedProjectSettings.hooksText`.
  public let hooks: String
  /// The sha256 of the file they were read from: what the answer is stored
  /// against, and what says whether the file has moved on under the
  /// question.
  public let digest: String

  public init(projectID: Project.ID, projectName: String, hooks: String, digest: String) {
    self.projectID = projectID
    self.projectName = projectName
    self.hooks = hooks
    self.digest = digest
  }

  public var id: String { projectID }

  public var title: String {
    t("shared-hooks.title", projectName, SharedProjectSettings.fileName)
  }

  public var message: String { t("shared-hooks.message", hooks) }

  public var trustLabel: String { t("shared-hooks.trust") }
  public var declineLabel: String { t("shared-hooks.decline") }
}
