import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

extension AppModel {
  /// The remote a branch with none of its own is pushed to: `origin`, as git
  /// clones it, else the first listed.
  private static var preferredRemoteName: String { "origin" }

  /// Create Pull Request's question before it pushes, until it is answered.
  public internal(set) var pendingBranchPublish: PendingBranchPublish? {
    get { remoteState.pendingBranchPublish }
    set { remoteState.pendingBranchPublish = newValue }
  }

  /// `nil` where the project has no host turned on, the host said the
  /// repository is not its own, or the branch is the trunk or none at all.
  public func pullRequestMenuItem(for worktree: Worktree) -> PullRequestMenuItem? {
    // Unread is not "none": Create would be offered for a branch that has one.
    guard let project = workspace.project(worktree.projectID), pullRequestHost(for: project) != nil,
      let reading = remoteState.pullRequests[project.id], reading.hasAnswered,
      reading.failure != .notHosted, pullRequestBranch(of: worktree, in: project) != nil
    else { return nil }
    // A closed one stays shown, but the host takes a new one from the branch.
    if let pullRequest = services(of: worktree).pullRequest, pullRequest.state != .closed {
      return .open(number: pullRequest.number)
    }
    return .create(isPublishing: isPublishing(worktree))
  }

  public func openPullRequest(of worktree: Worktree) async {
    guard let project = workspace.project(worktree.projectID),
      let (integration, host) = pullRequestHost(for: project),
      let pullRequest = services(of: worktree).shownPullRequest
    else { return }
    do {
      try await host.open(pullRequest, in: worktree.path)
    } catch {
      present(ServiceOpenFailure(integration: integration, underlying: error))
    }
  }

  /// A check's page, where its host gave a web link; nothing else is opened.
  public func openCheck(_ check: PullRequestCheck) {
    guard let page = check.webPage else { return }
    platform.openWebPage(page)
  }

  /// The host's new pull request page against the trunk. A branch the remote
  /// lacks, or commits it lacks, is asked about first; see services.md.
  public func createPullRequest(for worktree: Worktree) async {
    guard let project = workspace.project(worktree.projectID), let coordinator,
      let branch = worktree.branch, pullRequestHost(for: project) != nil,
      // Its reads can take a while on a slow network; a second click waits.
      remoteState.publishingWorktrees.insert(worktree.id).inserted
    else { return }
    defer { remoteState.publishingWorktrees.remove(worktree.id) }
    let step = await pullRequestCreationStep(
      for: worktree,
      branch: branch,
      in: project,
      using: coordinator.git,
    )
    // One removed while git asked has nothing left to push, open or report.
    guard workspace.worktree(worktree.id) != nil else { return }
    switch step {
    case .ask(let question):
      // One question at a time: another worktree's still waits on its answer.
      guard pendingBranchPublish == nil else { return }
      pendingBranchPublish = question

    case .fail(let error):
      present(error)

    case .open(let head, let remote):
      await openNewPullRequest(of: worktree, head: head, on: remote)
    }
  }

  /// Push, then the new pull request page; No leaves the branch as it is.
  public func answerBranchPublish(_ pending: PendingBranchPublish, publishes: Bool) {
    // SwiftUI may clear the dialog's binding, answering No, before running
    // Push; a Push still stands then, but never over another question.
    let answersThisQuestion =
      pendingBranchPublish == pending || (publishes && pendingBranchPublish == nil)
    guard answersThisQuestion else { return }
    pendingBranchPublish = nil
    guard publishes else { return }
    Task { await publishThenCreatePullRequest(pending) }
  }

  /// The branch a pull request could head: none for the trunk or a bare repository.
  func pullRequestBranch(of worktree: Worktree, in project: Project) -> String? {
    // The usual name stands in for a trunk not yet or never resolved.
    guard !worktree.isBare, let branch = worktree.branch, branch != defaultBranchName(of: project)
    else { return nil }
    return branch
  }

  func isPublishing(_ worktree: Worktree) -> Bool {
    remoteState.publishingWorktrees.contains(worktree.id)
  }

  /// What Create does once git says what the remote lacks.
  private func pullRequestCreationStep(
    for worktree: Worktree,
    branch: String,
    in project: Project,
    using git: WorktreeGit,
  ) async -> PullRequestCreationStep {
    var upstream = remoteState.upstreams[worktree.id]
    // Asked now, not trusted from the last read: the page would open against
    // a branch the remote has since deleted, or without a commit made since.
    if let tracked = upstream, tracked.tip != nil,
      await git.remoteHasBranch(tracked.branch, on: tracked.remote, in: worktree.path) == false
    {
      upstream = tracked.goneFromRemote
    }
    // Counted against where it is published, which it may not track.
    var unpushed: Int?
    if let tip = upstream?.tip {
      unpushed = await git.commitCount(ofBranch: branch, past: tip, in: worktree.path)
      if unpushed == nil { return .fail(UnpushedCommitsUnknown(branch: branch)) }
    }
    if let upstream, upstream.tip != nil, unpushed == 0 {
      return .open(head: upstream.branch, remote: upstream.remote)
    }
    let remotes = await git.remotes(project)
    let pushRemote = await git.pushRemote(ofBranch: branch, in: worktree.path)
    // git pushes to a remote config names apart from what is followed, which
    // lacks the branch or the scan would have found it; an unread list fails.
    if let followed = upstream?.remote, let pushRemote, pushRemote != followed,
      remotes?.contains(where: { $0.name == pushRemote }) != false
    {
      upstream = nil
      unpushed = nil
    }
    let remote: String
    if let upstream {
      remote = upstream.remote
    } else {
      guard let remotes else { return .fail(RemotesUnknown(branch: branch)) }
      guard
        let chosen = remotes.first(where: { $0.name == pushRemote })
          ?? remotes.first(where: { $0.name == Self.preferredRemoteName }) ?? remotes.first
      else { return .fail(NoRemoteToPublishTo(branch: branch)) }
      remote = chosen.name
    }
    // A branch with no upstream of its own may still share a name with one
    // the remote has, which the question must not call new.
    let remoteHasBranch =
      upstream == nil
      ? await git.remoteHasBranch(branch, on: remote, in: worktree.path) == true
      : false
    return .ask(
      PendingBranchPublish(
        worktree: worktree,
        branch: branch,
        remote: remote,
        remoteBranch: upstream?.branch ?? branch,
        unpushedCommits: unpushed,
        remoteHasBranch: remoteHasBranch,
      )
    )
  }

  private func publishThenCreatePullRequest(_ pending: PendingBranchPublish) async {
    guard let coordinator, remoteState.publishingWorktrees.insert(pending.worktree.id).inserted
    else { return }
    defer { remoteState.publishingWorktrees.remove(pending.worktree.id) }
    do {
      try await coordinator.git.publish(
        pending.branch,
        as: pending.remoteBranch,
        to: pending.remote,
        in: pending.worktree.path,
      )
    } catch {
      present(BranchPublishFailure(branch: pending.branch, underlying: error))
      return
    }
    // The page opens from what was pushed, whatever the scan after it finds.
    guard let project = workspace.project(pending.worktree.projectID),
      let worktree = workspace.worktree(pending.worktree.id)
    else { return }
    await refreshBranchScan(of: project)
    await openNewPullRequest(of: worktree, head: pending.remoteBranch, on: pending.remote)
  }

  private func openNewPullRequest(of worktree: Worktree, head: String, on remote: String) async {
    guard let project = workspace.project(worktree.projectID),
      let (integration, host) = pullRequestHost(for: project)
    else { return }
    let headRepository = remoteState.pullRequests[project.id].flatMap { reading in
      RemoteRepository(pushedTo: remote, among: reading.remotes)
    }
    do {
      try await host.openNewPullRequest(
        head: head,
        in: headRepository,
        base: defaultBranchName(of: project),
        directory: worktree.path,
      )
    } catch {
      present(ServiceOpenFailure(integration: integration, underlying: error))
    }
  }
}
