import MultishellCore

/// The one-time question about what a repository's `.multishell.json` asks
/// to run or read, remembered against the file's sha256; see settings.md.
public struct PendingSharedSettingsTrust: Identifiable, Equatable, Sendable {
  public let projectID: Project.ID
  public let projectName: String
  /// What the file asks for, as shown:
  /// `SharedProjectSettings.trustCoveredText`.
  public let contents: String
  /// The sha256 of the file they were read from: what the answer is stored
  /// against, and what says whether the file has moved on.
  let digest: String

  init(projectID: Project.ID, projectName: String, contents: String, digest: String) {
    self.projectID = projectID
    self.projectName = projectName
    self.contents = contents
    self.digest = digest
  }

  public var id: String { projectID }

  public var title: String {
    t("shared-settings.title", projectName, SharedProjectSettings.fileName)
  }

  public var message: String { t("shared-settings.message", contents) }

  public var trustLabel: String { t("shared-settings.trust") }
  public var declineLabel: String { t("shared-settings.decline") }
}
