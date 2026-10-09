import MultishellCore

extension InheritedSetting where Value == String {
  /// Where the project's worktrees land, naming the repository's file while
  /// it chose the directory and no override has replaced it.
  func containerCaption(_ container: String, isOverridden: Bool) -> String {
    namesRepositoryFile(isOverridden: isOverridden)
      ? t("project.resolves-to-shared", container, SharedProjectSettings.fileName)
      : t("project.resolves-to", container)
  }

  /// What a typed branch would become and where, naming the file the prefix
  /// came from on the same terms.
  func prefixExampleCaption(branch: String, path: String, isOverridden: Bool) -> String {
    namesRepositoryFile(isOverridden: isOverridden)
      ? t(
        "project.prefix-example-shared",
        WorktreeSettings.exampleBranchName,
        branch,
        path,
        SharedProjectSettings.fileName,
      )
      : t("project.prefix-example", WorktreeSettings.exampleBranchName, branch, path)
  }

  private func namesRepositoryFile(isOverridden: Bool) -> Bool {
    !isOverridden && isFromRepository
  }
}
