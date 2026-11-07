import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

extension WorktreeServices {
  /// A branch nobody pushed has no pull request or run to find, so `upstream`
  /// `nil` reads as none of either.
  init(
    upstream: BranchUpstream?,
    localTip: String?,
    localBranch: String?,
    pullRequests: ProjectPullRequests?,
    ciRuns: ProjectCIRuns?,
    answeredAt: (pullRequests: Date?, ciRuns: Date?) = (nil, nil),
    changesPastHead: [ChangesPastHead: Bool] = [:],
  ) {
    self.localTip = localTip
    if let pullRequests {
      pullRequestIntegration = pullRequests.integration
      let shown = upstream.flatMap { upstream in
        Self.headedPullRequest(of: upstream, in: pullRequests)
      }
      // Outgrown where git says the tip has a change of its own the head lacks:
      // one behind it, or synced from another branch, left nothing out.
      changesPastMergedHead = shown.flatMap { pullRequest in
        Self.changesPastMergedHead(
          of: pullRequest,
          localTip: localTip,
          localBranch: localBranch,
          upstream: upstream,
        )
      }
      if changesPastMergedHead.flatMap({ changesPastHead[$0] }) == true {
        outgrownPullRequest = shown
      } else {
        pullRequest = shown
      }
    }
    if let ciRuns {
      ciIntegration = ciRuns.integration
      ciRun = upstream.flatMap { upstream in
        ciRuns.runsByBranch[upstream.branch].flatMap { run in
          Self.ran(
            run,
            inRepositoryOf: upstream,
            remotes: ciRuns.remotes,
            currentRepositories: pullRequests?.currentRepositories ?? [:],
          ) ? run : nil
        }
      }
    }
    readProblem = Self.readProblem(
      pullRequests: pullRequests,
      ciRuns: ciRuns,
      branch: upstream?.branch,
      answeredAt: answeredAt,
    )
  }

  private static func changesPastMergedHead(
    of pullRequest: PullRequest,
    localTip: String?,
    localBranch: String?,
    upstream: BranchUpstream?,
  ) -> ChangesPastHead? {
    guard pullRequest.state == .merged, let localTip, pullRequest.headCommit != localTip,
      let localBranch, let upstream
    else { return nil }
    return ChangesPastHead(
      head: pullRequest.headCommit,
      tip: localTip,
      ownRemoteBranch: "\(upstream.remote)/\(upstream.branch)",
      ownBranch: localBranch,
    )
  }

  /// Headed by the upstream branch in the repository its remote's URL names,
  /// so a fork's same-named branch is not taken for this one.
  private static func headedPullRequest(
    of upstream: BranchUpstream,
    in reading: ProjectPullRequests,
  ) -> PullRequest? {
    let repositories = PushedRepositories.of(
      remote: upstream.remote,
      among: reading.remotes,
      currentRepositories: reading.currentRepositories,
    )
    let headed = reading.pullRequests.filter { pullRequest in
      pullRequest.headBranch == upstream.branch
        && repositories.contains(where: pullRequest.headRepository.isSame(as:))
    }
    return headed.filter { !$0.state.isSettled }.max(by: { $0.updatedAt < $1.updatedAt })
      ?? headed.max(by: { $0.updatedAt < $1.updatedAt })
  }

  /// A fork's branch of the same name ran somewhere else. Where either side
  /// is unsaid, the name alone decides.
  static func ran(
    _ run: CIRun,
    inRepositoryOf upstream: BranchUpstream,
    remotes: [GitRemote],
    currentRepositories: [String: RemoteRepository],
  ) -> Bool {
    let pushedTo = PushedRepositories.of(
      remote: upstream.remote,
      among: remotes,
      currentRepositories: currentRepositories,
    )
    guard let ranIn = run.repository, !pushedTo.isEmpty else { return true }
    return pushedTo.contains(where: ranIn.isSame(as:))
  }

  private static func readProblem(
    pullRequests: ProjectPullRequests?,
    ciRuns: ProjectCIRuns?,
    branch: String?,
    answeredAt: (pullRequests: Date?, ciRuns: Date?),
  ) -> ServiceReadProblem? {
    if let pullRequests, let failure = pullRequests.failure, failure != .notHosted {
      return ServiceReadProblem(
        source: .pullRequests,
        integration: pullRequests.integration,
        failure: failure,
        lastAnsweredAt: answeredAt.pullRequests,
      )
    }
    if let ciRuns,
      let failure = ciRuns.failure ?? branch.flatMap({ ciRuns.branchFailures[$0] }),
      failure != .notHosted
    {
      return ServiceReadProblem(
        source: .ciRuns,
        integration: ciRuns.integration,
        failure: failure,
        lastAnsweredAt: answeredAt.ciRuns,
      )
    }
    return nil
  }
}
