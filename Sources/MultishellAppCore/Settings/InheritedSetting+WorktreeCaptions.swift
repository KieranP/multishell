import MultishellCore

extension InheritedSetting where Value == String {
  /// Where the project's worktrees land, naming the repository's file while
  /// it chose the directory and no override has replaced it.
  public func containerCaption(_ container: String, isOverridden: Bool) -> String {
    namesRepositoryFile(isOverridden: isOverridden)
      ? t("project.resolves-to-shared", container, SharedProjectSettings.fileName)
      : t("project.resolves-to", container)
  }

  /// What a typed branch would become and where, naming the file the prefix
  /// came from on the same terms.
  public func prefixExampleCaption(branch: String, path: String, isOverridden: Bool) -> String {
    namesRepositoryFile(isOverridden: isOverridden)
      ? t("project.prefix-example-shared", branch, path, SharedProjectSettings.fileName)
      : t("project.prefix-example", branch, path)
  }

  private func namesRepositoryFile(isOverridden: Bool) -> Bool {
    !isOverridden && isFromRepository
  }
}
