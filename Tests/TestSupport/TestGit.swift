import MultishellGitKit

/// How a test gets git.
public enum TestGit {
  /// Real git with commit signing off, and any `configuration` the caller
  /// adds on top. A developer whose global config signs, through an agent
  /// that asks before it hands over the key, would otherwise be asked once
  /// per fixture commit. The override rides on the runner rather than on
  /// each repository's config, so a clone or a bare repository a later test
  /// adds is covered without being told.
  public static func build(configuration: [String: String] = [:]) throws -> GitRunner {
    try GitRunner(
      configuration: ["commit.gpgsign": "false"].merging(configuration) { _, added in added })
  }
}
