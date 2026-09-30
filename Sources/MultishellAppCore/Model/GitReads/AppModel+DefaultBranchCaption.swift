import MultishellCore

extension AppModel {
  /// What the default-branch override says under its field: the branch merges
  /// are measured against, or that there is none and so no merged badge.
  public func defaultBranchCaption(for project: Project) -> String {
    defaultBranch(of: project).map { t("project.merges-measured", $0.shortName) }
      ?? t("project.no-merge-base")
  }
}
