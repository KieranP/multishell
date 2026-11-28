import Foundation
import TestScratch

@testable import MultishellGitKit

public enum TestGit {
  /// A commit starts `git maintenance` detached, which wrote a lock into the repository
  /// template while tests copied it, failing the copy.
  private static let automaticMaintenance = "false"

  /// Signing is off, or a signing agent asks for the key once per fixture commit, and SSH
  /// is refused, so a remote spelled as GitHub's is never dialled. All ride on the runner.
  public static func runner(
    executable: URL? = nil,
    searchPath: String? = nil,
    loginVariables: [String: String] = [:],
    configuration: [String: String] = [:],
  ) throws -> GitRunner {
    let fixture = [
      "commit.gpgsign": "false", "core.sshCommand": "false",
      "maintenance.auto": automaticMaintenance,
    ]
    let merged = fixture.merging(configuration) { _, added in added }
    guard let executable else {
      return try GitRunner(
        searchPath: searchPath,
        loginVariables: loginVariables,
        configuration: merged,
      )
    }
    return try GitRunner(
      executable: executable,
      searchPath: searchPath,
      loginVariables: loginVariables,
      configuration: merged,
    )
  }

  /// A runner whose git is a script at `url` running `prelude`, then the real git.
  public static func runner(wrappingRealGitIn prelude: String, at url: URL) throws -> GitRunner {
    try runner(executable: try Scratch.script(prelude + "\nexec git \"$@\"", at: url))
  }

  /// No index settling, which would spend a run of a fake git on every add.
  public static func coordinator(runner: GitRunner) -> WorktreeCoordinator {
    WorktreeCoordinator(git: WorktreeGit(runner: runner, settlesNewIndex: false))
  }
}
