@testable import MultishellGitKit

public enum TestGit {
  /// Signing is off, or a signing agent asks for the key once per fixture commit, and SSH
  /// is refused, so a remote spelled as GitHub's is never dialled. Both ride on the runner.
  public static func runner(
    searchPath: String? = nil,
    configuration: [String: String] = [:],
  ) throws -> GitRunner {
    try GitRunner(
      searchPath: searchPath,
      configuration: ["commit.gpgsign": "false", "core.sshCommand": "false"].merging(configuration)
      { _, added in added },
    )
  }

  /// No index settling, which would spend a run of a fake git on every add.
  public static func coordinator(runner: GitRunner) -> WorktreeCoordinator {
    WorktreeCoordinator(git: WorktreeGit(runner: runner, settlesNewIndex: false))
  }
}
