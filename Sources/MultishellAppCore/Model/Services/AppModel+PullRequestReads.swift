import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

extension AppModel {
  private static var concurrentBranchPullRequestLookups: Int { 4 }
  private static var concurrentRepositoryAsks: Int { 4 }

  /// One list call for the whole project, and alone each pushed branch it left
  /// out. A failure keeps the list before it; see Docs/design/services/reads.md.
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
      await resolveCurrentRepositories(in: &reading, with: host, in: project.path)
      let lookups = try await lookUpBranches(
        leftOutBy: listed,
        of: project,
        reading: reading,
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

  /// What each remote's push URL names today, asked once a URL while its remote
  /// stays; one that failed waits out `ServiceReadInterval`'s recheck.
  private func resolveCurrentRepositories(
    in reading: inout ProjectPullRequests,
    with host: any PullRequestHost,
    in directory: URL,
  ) async {
    let remotes = reading.remotes
    let urls = Set(
      remotes.compactMap { remote in
        RemoteRepository(pushedTo: remote.name, among: remotes).map { _ in
          remote.pushURL ?? remote.url
        }
      }
    )
    reading.currentRepositories = reading.currentRepositories.filter { urls.contains($0.key) }
    reading.remoteURLAskFailures = reading.remoteURLAskFailures.filter { urls.contains($0.key) }
    let failures = reading.remoteURLAskFailures
    let asking = urls.subtracting(reading.currentRepositories.keys).filter { url in
      !ServiceReadInterval.unresolvedRemoteStands(since: failures[url])
    }
    let answers = await asking.sorted().mapConcurrentlyUnordered(
      width: Self.concurrentRepositoryAsks
    ) { url -> (String, RemoteRepository?) in
      (url, try? await host.repository(namedBy: url, in: directory))
    }
    for (url, answer) in answers {
      if let answer {
        reading.currentRepositories[url] = answer
        reading.remoteURLAskFailures[url] = nil
      } else {
        reading.remoteURLAskFailures[url] = .now
      }
    }
  }

  /// Each worktree's branch on the remote that no listed pull request heads in
  /// its repository, gone or not. Not the trunk: forks open pull requests from theirs.
  private func branchesLeftOut(
    by listed: [PullRequest],
    of project: Project,
    reading: ProjectPullRequests,
  ) -> [String: String?] {
    let trunk = defaultBranchName(of: project)
    var branches: [String: String?] = [:]
    for worktree in workspace.worktrees(of: project.id) {
      guard let upstream = remoteState.upstreams[worktree.id], upstream.branch != trunk else {
        continue
      }
      let repositories = PushedRepositories.of(
        remote: upstream.remote,
        among: reading.remotes,
        currentRepositories: reading.currentRepositories,
      )
      // A remote whose URL names no repository takes any pull request its branch heads.
      let isListed = listed.contains { pullRequest in
        pullRequest.headBranch == upstream.branch
          && (repositories.isEmpty
            || repositories.contains(where: pullRequest.headRepository.isSame(as:)))
      }
      if !isListed { branches[upstream.branch] = upstream.tip }
    }
    return branches
  }

  /// Any branch failing to answer fails the read, which keeps the lookups before it.
  private func lookUpBranches(
    leftOutBy listed: [PullRequest],
    of project: Project,
    reading: ProjectPullRequests,
    with host: any PullRequestHost,
    reusing previous: [String: BranchPullRequestLookup],
  ) async throws -> [String: BranchPullRequestLookup] {
    var lookups: [String: BranchPullRequestLookup] = [:]
    var asking: [(branch: String, tip: String?)] = []
    for (branch, tip) in branchesLeftOut(by: listed, of: project, reading: reading) {
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
