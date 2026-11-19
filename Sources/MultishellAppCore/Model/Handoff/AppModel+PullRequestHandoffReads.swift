import Foundation
import MultishellCore
import MultishellServices

/// What a PR page Send reads: on the page, what it read as it went; off it, read
/// at the Send, as nothing keeps it current there.
extension AppModel {
  /// The checks a Send carries and the head they ran on: on the PR page, as it
  /// read them; off it, read now, the head beside them, as a push moves both.
  func checksToSend(
    of pullRequest: PullRequest,
    in worktree: Worktree,
    with host: any PullRequestHost,
  ) async -> Result<PullRequestChecks, ServiceReadFailure> {
    if pullRequestPageKeepsPace(of: worktree) {
      let reading = checksReading(of: pullRequest, in: worktree)
      if reading?.checks == nil, let failure = reading?.failure { return .failure(failure) }
      return .success(
        PullRequestChecks(
          pullRequestNumber: pullRequest.number,
          headCommit: pullRequest.headCommit,
          checks: reading?.checks,
        )
      )
    }
    do {
      async let checks = host.checks(of: pullRequest, in: worktree.path)
      async let head = host.headCommit(of: pullRequest, in: worktree.path)
      return .success(
        PullRequestChecks(
          pullRequestNumber: pullRequest.number,
          headCommit: try await head,
          checks: try await checks,
        )
      )
    } catch {
      return .failure(ServiceReadFailure(error))
    }
  }

  /// The threads a Send carries: on the PR page, as it read them, its failure where
  /// that read failed, none it has yet to show; off it, read now.
  func threadsToSend(
    of pullRequest: PullRequest,
    in worktree: Worktree,
    with host: any PullRequestHost,
  ) async -> Result<[PullRequestThread], ServiceReadFailure> {
    guard !pullRequest.state.isSettled else { return .success([]) }
    if pullRequestPageKeepsPace(of: worktree) {
      guard let reading = remoteState.threads[worktree.id],
        reading.pullRequestNumber == pullRequest.number
      else {
        // A box nobody has seen is not sent checked.
        return .success([])
      }
      if let threads = reading.threads { return .success(threads) }
      return reading.failure.map { .failure($0) } ?? .success([])
    }
    do {
      return .success(try await host.unresolvedThreads(of: pullRequest, in: worktree.path))
    } catch {
      return .failure(ServiceReadFailure(error))
    }
  }

  /// The PR page on the panel for this worktree, with the app frontmost: the one
  /// place its reads keep pace, as they pause in the background.
  private func pullRequestPageKeepsPace(of worktree: Worktree) -> Bool {
    isFilesPanelShowing(.pullRequest) && filesPanelWorktree?.id == worktree.id
      && platform.isActive
  }
}
