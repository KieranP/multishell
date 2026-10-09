import MultishellCore

extension WorktreeGit {
  private static let fetchTimeout: Duration = .seconds(120)

  /// `git fetch --prune`, on the user's click only: the one git call here
  /// that talks to a network. `GIT_TERMINAL_PROMPT=0`, and a timeout.
  public func fetch(_ project: Project) async throws {
    _ = try await runner.run(
      ["fetch", "--prune", "--quiet"],
      in: project.path,
      environment: ["GIT_TERMINAL_PROMPT": "0"],
      timeout: Self.fetchTimeout,
    )
  }
}
