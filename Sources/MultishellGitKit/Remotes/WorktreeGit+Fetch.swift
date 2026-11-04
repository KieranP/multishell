import MultishellCore

extension WorktreeGit {
  private static let fetchTimeout: Duration = .seconds(120)

  /// `git fetch --prune`, on the user's click only: it talks to a network, so
  /// no prompt and a timeout.
  public func fetch(_ project: Project) async throws {
    _ = try await runner.run(
      ["fetch", "--prune", "--quiet"],
      in: project.path,
      environment: Self.networkEnvironment,
      timeout: Self.fetchTimeout,
    )
  }
}
