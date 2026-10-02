@testable import MultishellGitKit

public enum TestGit {
  /// Signing is off, or a signing agent that asks for the key asks once per fixture commit. It
  /// rides on the runner, so a clone or bare repository a later test adds is covered too.
  public static func runner(
    searchPath: String? = nil, configuration: [String: String] = [:]
  ) throws -> GitRunner {
    try GitRunner(
      searchPath: searchPath,
      configuration: ["commit.gpgsign": "false"].merging(configuration) { _, added in added })
  }

  /// No index settling, which would spend a run of a fake git on every add.
  public static func coordinator(runner: GitRunner) -> WorktreeCoordinator {
    WorktreeCoordinator(git: WorktreeGit(runner: runner, settlesNewIndex: false))
  }
}
