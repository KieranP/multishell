import Foundation

@testable import MultishellGitKit

public enum TestGit {
  /// Signing is off, or a signing agent asks for the key once per fixture commit, and SSH
  /// is refused, so a remote spelled as GitHub's is never dialled. Both ride on the runner.
  public static func runner(
    executable: URL? = nil,
    searchPath: String? = nil,
    configuration: [String: String] = [:],
  ) throws -> GitRunner {
    let fixture = ["commit.gpgsign": "false", "core.sshCommand": "false"]
    let merged = fixture.merging(configuration) { _, added in added }
    guard let executable else {
      return try GitRunner(searchPath: searchPath, configuration: merged)
    }
    return try GitRunner(executable: executable, searchPath: searchPath, configuration: merged)
  }

  /// No index settling, which would spend a run of a fake git on every add.
  public static func coordinator(runner: GitRunner) -> WorktreeCoordinator {
    WorktreeCoordinator(git: WorktreeGit(runner: runner, settlesNewIndex: false))
  }
}
