import MultishellCore
import MultishellGitKit

extension AppModel {
  /// The branch this project's merges are measured against, `nil` while
  /// none has been resolved. What the settings panel shows as detected.
  func defaultBranch(of project: Project) -> DefaultBranch? {
    defaultBranches[project.id]
  }

  /// What the default-branch field shows while not overridden, and seeds an
  /// override with: the detected branch without its remote, else the usual.
  public func defaultBranchName(of project: Project) -> String {
    defaultBranch(of: project)?.nameWithoutRemote ?? Self.usualDefaultBranchName
  }

  public static var usualDefaultBranchName: String { "main" }

  /// What the default-branch override says under its field: the branch merges
  /// are measured against, or that there is none and so no merged badge.
  public func defaultBranchCaption(for project: Project) -> String {
    defaultBranch(of: project).map { t("project.merges-measured", $0.shortName) }
      ?? t("project.no-merge-base")
  }
}
