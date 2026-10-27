import MultishellCore
import MultishellGitKit
import MultishellServices

extension AppModel {
  public func pullRequestPage(of worktree: Worktree) -> PullRequestPage {
    guard let project = workspace.project(worktree.projectID), pullRequestHost(for: project) != nil
    else { return .turnedOff }
    let reading = remoteState.pullRequests[project.id]
    if reading?.failure == .notHosted { return .notHosted }
    if let pullRequest = services(of: worktree).shownPullRequest {
      return .pullRequest(pullRequest)
    }
    guard let branch = pullRequestBranch(of: worktree, in: project) else { return .notApplicable }
    guard reading?.hasAnswered == true else {
      return .notRead(problem: reading.flatMap { $0.failure?.reason(integration: $0.integration) })
    }
    return .noPullRequest(
      branch: branch,
      isPushed: remoteState.upstreams[worktree.id]?.tip != nil,
    )
  }

  public func ciPage(of worktree: Worktree) -> CIPage {
    guard let project = workspace.project(worktree.projectID), ciProvider(for: project) != nil
    else { return .turnedOff }
    let reading = remoteState.ciRuns[project.id]
    if reading?.isConfigured == false { return .notConfigured }
    if let reading, reading.failure == .notHosted {
      return .notHosted(provider: reading.integration.displayName)
    }
    guard let branch = worktree.branch, !worktree.isBare else { return .notApplicable }
    guard let upstream = remoteState.upstreams[worktree.id] else {
      return .notPushed(branch: branch)
    }
    if let newest = ciHistory(of: worktree)?.runs.first ?? services(of: worktree).ciRun {
      return .run(newest)
    }
    guard reading?.hasAnswered == true else {
      return .notRead(problem: reading.flatMap { $0.failure?.reason(integration: $0.integration) })
    }
    return .noRuns(branch: upstream.branch)
  }

  /// What decides whether the shown pull request can merge, from its
  /// checks once read.
  public func mergeReadiness(of pullRequest: PullRequest, in worktree: Worktree) -> MergeReadiness {
    // An earlier head's checks say nothing of this one's.
    let checks = remoteState.checks[worktree.id].flatMap { reading in
      reading.pullRequestNumber == pullRequest.number
        && reading.headCommit == pullRequest.headCommit
        ? reading.checks : nil
    }
    return MergeReadiness(pullRequest, checks: checks)
  }

  /// Why the page's own read, the checks or the run history, gave no answer.
  public func panelReadProblem(of worktree: Worktree) -> String? {
    guard let project = workspace.project(worktree.projectID) else { return nil }
    switch shownFilesPanelMode {
    case .ciRuns:
      guard let failure = ciHistory(of: worktree)?.failure,
        let (integration, _) = ciProvider(for: project)
      else { return nil }
      return failure.reason(integration: integration)

    case .pullRequest:
      guard let failure = remoteState.checks[worktree.id]?.failure,
        let (integration, _) = pullRequestHost(for: project)
      else { return nil }
      return failure.reason(integration: integration)

    case .files, .changes:
      return nil
    }
  }

  /// Who the pages name, from the project's own integrations: the page can
  /// draw from its own read before the row's services have any.
  public func ciProviderName(of worktree: Worktree) -> String? {
    workspace.project(worktree.projectID).flatMap(ciProvider(for:))?.0.displayName
  }

  public func pullRequestHostName(of worktree: Worktree) -> String? {
    workspace.project(worktree.projectID).flatMap(pullRequestHost(for:))?.0.displayName
  }

  /// The runs before the newest, for the page's Earlier Runs.
  public func earlierCIRuns(of worktree: Worktree) -> [CIRun] {
    Array(ciHistory(of: worktree)?.runs.dropFirst() ?? [])
  }

  /// The history read, where it is of the branch the worktree follows now.
  func ciHistory(of worktree: Worktree) -> CIRunHistory? {
    guard let history = remoteState.ciHistories[worktree.id],
      history.branch == remoteState.upstreams[worktree.id]?.branch
    else { return nil }
    return history
  }
}
