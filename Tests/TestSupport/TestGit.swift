import MultishellGitKit

/// How a test gets git.
public enum TestGit {
  /// Signing is off, or a signing agent that asks for the key asks once per fixture commit. It
  /// rides on the runner, so a clone or bare repository a later test adds is covered too.
  public static func build(
    path: String? = nil, configuration: [String: String] = [:]
  ) throws -> GitRunner {
    try GitRunner(
      path: path,
      configuration: ["commit.gpgsign": "false"].merging(configuration) { _, added in added })
  }
}
