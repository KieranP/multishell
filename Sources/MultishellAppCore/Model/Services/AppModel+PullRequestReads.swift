import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

extension AppModel {
  private static var concurrentBranchPullRequestLookups: Int { 4 }

  /// One list call for the whole project, and alone each pushed branch it left
  /// out. A failure keeps the list before it; see Docs/design/services.md.
  func readPullRequests(
    of project: Project,
    remotes: [GitRemote]?,
    after previous: ProjectPullRequests?,
  ) async -> ProjectPullRequests? {
    guard let (integration, host) = pullRequestHost(for: project) else { return nil }
    // A failed git read is not a repository without remotes.
    guard let remotes else { return previous }
    let changesBefore = remoteState.integrationChanges[project.id]
    var reading =
      previous.flatMap { $0.integration == integration ? $0 : nil }
      ?? ProjectPullRequests(integration: integration, pullRequests: [], remotes: remotes)
    // The host decides "not ours" from the remotes and its logins, so the
    // same remotes get the same answer until a login may have changed it.
    if reading.failure == .notHosted, reading.remotes == remotes,
      ServiceReadInterval.notHostedStands(since: reading.notHostedSince)
    {
      return reading
    }
    reading.remotes = remotes
    do {
      let listed = try await host.pullRequests(in: project.path)
      let lookups = try await lookUpBranches(
        leftOutBy: listed,
        of: project,
        remotes: remotes,
        with: host,
        reusing: reading.lookups,
      )
      reading.pullRequests =
        listed + lookups.sorted { $0.key < $1.key }.flatMap(\.value.pullRequests)
      reading.lookups = lookups
      reading.hasAnswered = true
      // Gone, or its integrations changed, while `gh` ran: nothing stands to date.
      if workspace.project(project.id) != nil,
        remoteState.integrationChanges[project.id] == changesBefore
      {
        remoteState.pullRequestsAnsweredAt[project.id] = .now
      }
      reading.failure = nil
      reading.notHostedSince = nil
    } catch {
      reading.failure = ServiceReadFailure(error)
      if reading.failure == .notHosted {
        reading.pullRequests = []
        reading.lookups = [:]
        reading.notHostedSince = .now
      }
    }
    return reading
  }

  /// Each worktree's branch on the remote that no listed pull request heads in
  /// its repository, gone or not. Not the trunk: forks open pull requests from theirs.
  private func branchesLeftOut(
    by listed: [PullRequest],
    of project: Project,
    remotes: [GitRemote],
  ) -> [String: String?] {
    let trunk = defaultBranchName(of: project)
    var branches: [String: String?] = [:]
    for worktree in workspace.worktrees(of: project.id) {
      guard let upstream = remoteState.upstreams[worktree.id], upstream.branch != trunk else {
        continue
      }
      let repository = RemoteRepository(pushedTo: upstream.remote, among: remotes)
      let isListed = listed.contains { pullRequest in
        pullRequest.headBranch == upstream.branch
          && repository.map(pullRequest.headRepository.isSame(as:)) != false
      }
      if !isListed { branches[upstream.branch] = upstream.tip }
    }
    return branches
  }

  /// Any branch failing to answer fails the read, which keeps the lookups before it.
  private func lookUpBranches(
    leftOutBy listed: [PullRequest],
    of project: Project,
    remotes: [GitRemote],
    with host: any PullRequestHost,
    reusing previous: [String: BranchPullRequestLookup],
  ) async throws -> [String: BranchPullRequestLookup] {
    var lookups: [String: BranchPullRequestLookup] = [:]
    var asking: [(branch: String, tip: String?)] = []
    for (branch, tip) in branchesLeftOut(by: listed, of: project, remotes: remotes) {
      if let kept = previous[branch], kept.stillAnswers(upstreamTip: tip) {
        lookups[branch] = kept
      } else {
        asking.append((branch, tip))
      }
    }
    let directory = project.path
    let answers = await asking.mapConcurrentlyUnordered(
      width: Self.concurrentBranchPullRequestLookups
    ) { asked -> (String, String?, Result<[PullRequest], any Error>) in
      do {
        let pullRequests = try await host.pullRequests(headedBy: asked.branch, in: directory)
        return (asked.branch, asked.tip, .success(pullRequests))
      } catch {
        return (asked.branch, asked.tip, .failure(error))
      }
    }
    for (branch, tip, result) in answers {
      lookups[branch] = BranchPullRequestLookup(upstreamTip: tip, pullRequests: try result.get())
    }
    return lookups
  }
}
