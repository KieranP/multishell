import MultishellCore

/// The one-time question about what a repository's `.multishell.json` asks
/// to run or read, remembered against the file's sha256; see settings.md.
public struct PendingSharedSettingsTrust: Identifiable, Equatable, Sendable {
  let projectID: Project.ID
  let projectName: String
  /// The lines of the file the answer covers, not the whole file.
  let trustCoveredText: String
  /// The sha256 of the file they were read from: what the answer is stored
  /// against, and what says whether the file has moved on.
  let digest: String

  init(projectID: Project.ID, projectName: String, trustCoveredText: String, digest: String) {
    self.projectID = projectID
    self.projectName = projectName
    self.trustCoveredText = trustCoveredText
    self.digest = digest
  }

  public var id: String { projectID }

  public var title: String {
    t("shared-settings.title", projectName, SharedProjectSettings.fileName)
  }

  public var message: String { t("shared-settings.message", trustCoveredText) }

  public var trustLabel: String { t("shared-settings.trust") }
  public var declineLabel: String { t("shared-settings.decline") }
}
