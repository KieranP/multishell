import Foundation
import MultishellCore
import MultishellServices

/// Merging from the pull request page; see Docs/design/services.md.
extension AppModel {
  /// The form the page shows in its place, kept current by `reconcileMerges`.
  public func pendingMerge(of worktree: Worktree) -> PendingMerge? {
    guard let pending = remoteState.pendingMerges[worktree.id], !pending.isDismissed,
      pending.pullRequestURL == services(of: worktree).shownPullRequest?.url
    else { return nil }
    return pending
  }

  /// The banner's button: none while a merge the host accepted awaits the
  /// list, which still shows the pull request as it was before it.
  public func mergeAction(for readiness: MergeReadiness, in worktree: Worktree) -> MergeAction? {
    if let pending = remoteState.pendingMerges[worktree.id], pending.wasAccepted,
      pending.pullRequestURL == services(of: worktree).shownPullRequest?.url
    {
      return nil
    }
    return readiness.mergeAction
  }

  /// Cancel Auto-Merge is off while one is in flight; see `AutoMergeCancellation`.
  func isCancellingAutoMerge(of worktree: Worktree) -> Bool {
    guard let cancellation = remoteState.autoMergeCancellations[worktree.id] else { return false }
    return cancellation.pullRequestURL == services(of: worktree).shownPullRequest?.url
  }

  /// Whether the banner's button is off: only a cancel already in flight.
  public func isMergeActionBusy(_ action: MergeAction?, of worktree: Worktree) -> Bool {
    action == .cancelAutoMerge && isCancellingAutoMerge(of: worktree)
  }

  /// The readiness banner's button.
  public func perform(_ action: MergeAction, for worktree: Worktree) async {
    switch action {
    case .merge, .mergeWhenReady: await beginMerge(of: worktree)
    case .cancelAutoMerge: await cancelAutoMerge(of: worktree)
    }
  }

  /// Why the form has nothing to offer, in the host's words.
  public func mergeReadProblem(of worktree: Worktree) -> String? {
    guard let project = workspace.project(worktree.projectID),
      let (integration, _) = pullRequestHost(for: project),
      let failure = pendingMerge(of: worktree)?.readFailure
    else { return nil }
    return failure.reason(integration: integration)
  }

  public func chooseMergeMethod(_ method: PullRequestMergeMethod, for worktree: Worktree) {
    guard var pending = pendingMerge(of: worktree), pending.isEditable,
      pending.options?.methods.contains(method) == true
    else { return }
    pending.method = method
    remoteState.pendingMerges[worktree.id] = pending
  }

  public func setMergeSubject(_ subject: String, for worktree: Worktree) {
    editMergeMessage(of: worktree) { $0.subject = subject }
  }

  public func setMergeBody(_ body: String, for worktree: Worktree) {
    editMergeMessage(of: worktree) { $0.body = body }
  }

  public func restoreMergeMessage(for worktree: Worktree) {
    guard var pending = pendingMerge(of: worktree), let method = pending.method, pending.isEditable
    else { return }
    pending.edits[method] = nil
    remoteState.pendingMerges[worktree.id] = pending
  }

  /// Back to the page; a merge already sent is not called back. Done after one
  /// the host accepted keeps it, hidden, for the read `confirmMerge` asked for.
  public func dismissMergeForm(of worktree: Worktree) {
    guard var pending = pendingMerge(of: worktree), pending.phase != .sending else { return }
    guard let acceptedAt = pending.acceptedAt else {
      remoteState.pendingMerges[worktree.id] = nil
      return
    }
    pending.phase = .dismissed(acceptedAt: acceptedAt)
    remoteState.pendingMerges[worktree.id] = pending
  }

  /// The app's second write to a remote, after the push. The form is the
  /// question asked every time; see services.md for what it is held to.
  public func confirmMerge(of worktree: Worktree) async {
    guard let project = workspace.project(worktree.projectID),
      let (_, host) = pullRequestHost(for: project),
      let pullRequest = services(of: worktree).shownPullRequest,
      var pending = pendingMerge(of: worktree), let merge = pending.merge,
      pullRequest.url == pending.pullRequestURL
    else { return }
    pending.phase = .sending
    remoteState.pendingMerges[worktree.id] = pending
    var isAccepted = false
    do {
      try await host.merge(pullRequest, as: merge, in: worktree.path)
      isAccepted = true
    } catch {
      present(
        PullRequestMergeFailure(
          number: pullRequest.number,
          action: merge.waitsForChecks ? .mergeWhenReady : .merge,
          underlying: error,
        )
      )
    }
    // Dropped while `gh` ran, by the host turned off, or opened anew since.
    if var answered = remoteState.pendingMerges[worktree.id], answered.opening == pending.opening {
      answered.phase = isAccepted ? .accepted(at: .now) : .editing
      remoteState.pendingMerges[worktree.id] = answered
    }
    // A refusal for a moved head, or a merge that landed past its timeout,
    // shows in the list too.
    await refreshServices(ofProject: project.id)
  }

  /// Weighs each form and cancel against the list and the checks, run wherever
  /// either changes; a gone worktree drops both.
  func reconcileMerges(of ids: some Sequence<Worktree.ID>) {
    // Run on every scan and services read, almost always with neither to weigh.
    guard !remoteState.pendingMerges.isEmpty || !remoteState.autoMergeCancellations.isEmpty
    else { return }
    for id in ids
    where remoteState.pendingMerges[id] != nil || remoteState.autoMergeCancellations[id] != nil {
      let worktree = workspace.worktree(id)
      if let pending = remoteState.pendingMerges[id] {
        setIfChanged(
          \.remoteState.pendingMerges[id],
          worktree.flatMap { reconciled(pending, in: $0) },
        )
      }
      // Not when `gh` returns: a read begun before it would turn the button
      // back on beside auto-merge still on. Another or none shown says nothing.
      if let cancellation = remoteState.autoMergeCancellations[id] {
        let shown = worktree.flatMap { services(of: $0).shownPullRequest }
        if worktree == nil
          || (shown?.url == cancellation.pullRequestURL && shown?.autoMergesWhenReady == false)
        {
          remoteState.autoMergeCancellations[id] = nil
        }
      }
    }
  }

  /// A list answer from a read begun after the host accepted a merge or a cancel
  /// says where it stands, whoever turned auto-merge on or off since: both end.
  func settleMerges(ofProject id: Project.ID, listReadBegunAt began: ContinuousClock.Instant) {
    for worktree in workspace.worktrees(of: id) {
      if let acceptedAt = remoteState.pendingMerges[worktree.id]?.acceptedAt,
        acceptedAt < began
      {
        remoteState.pendingMerges[worktree.id] = nil
      }
      if let acceptedAt = remoteState.autoMergeCancellations[worktree.id]?.acceptedAt,
        acceptedAt < began
      {
        remoteState.autoMergeCancellations[worktree.id] = nil
      }
    }
  }

  /// Merge or Merge When Ready: the page turns to the form, and the host is
  /// asked what it allows and what it would write.
  func beginMerge(of worktree: Worktree) async {
    guard let project = workspace.project(worktree.projectID),
      let (_, host) = pullRequestHost(for: project),
      let pullRequest = services(of: worktree).shownPullRequest,
      let action = mergeAction(for: mergeReadiness(of: pullRequest, in: worktree), in: worktree),
      action != .cancelAutoMerge, pendingMerge(of: worktree) == nil
    else { return }
    let opened = PendingMerge(of: pullRequest, waitsForChecks: action == .mergeWhenReady)
    remoteState.pendingMerges[worktree.id] = opened
    let answer: Result<PullRequestMergeOptions, ServiceReadFailure>
    do {
      answer = .success(try await host.mergeOptions(of: pullRequest, in: worktree.path))
    } catch {
      answer = .failure(ServiceReadFailure(error))
    }
    // Cancelled, or turned back by a push, while `gh` ran.
    guard var pending = remoteState.pendingMerges[worktree.id], pending.opening == opened.opening
    else { return }
    switch answer {
    case .success(let options):
      pending.options = options
      pending.method = options.defaultMethod

    case .failure(let failure):
      pending.readFailure = failure
    }
    remoteState.pendingMerges[worktree.id] = pending
  }

  /// Asks nothing first: it only takes back a merge not yet made. Off until the
  /// list shows it taken back; see `reconcileMerges`.
  func cancelAutoMerge(of worktree: Worktree) async {
    guard let project = workspace.project(worktree.projectID),
      let (_, host) = pullRequestHost(for: project),
      let pullRequest = services(of: worktree).shownPullRequest,
      pullRequest.autoMergesWhenReady,
      remoteState.autoMergeCancellations[worktree.id] == nil
    else { return }
    let cancellation = AutoMergeCancellation(pullRequestURL: pullRequest.url)
    remoteState.autoMergeCancellations[worktree.id] = cancellation
    var isAccepted = false
    do {
      try await host.disableAutoMerge(of: pullRequest, in: worktree.path)
      isAccepted = true
    } catch {
      present(
        PullRequestMergeFailure(
          number: pullRequest.number,
          action: .cancelAutoMerge,
          underlying: error,
        )
      )
    }
    // Dropped while `gh` ran, by the host turned off, and perhaps clicked anew.
    if remoteState.autoMergeCancellations[worktree.id]?.attempt == cancellation.attempt {
      if isAccepted {
        remoteState.autoMergeCancellations[worktree.id]?.acceptedAt = .now
      } else {
        remoteState.autoMergeCancellations[worktree.id] = nil
      }
    }
    await refreshServices(ofProject: project.id)
  }

  /// `nil` where the pull request is gone, closed, merged or pushed to, or
  /// now blocked for good; a merge being sent is left to finish.
  private func reconciled(_ pending: PendingMerge, in worktree: Worktree) -> PendingMerge? {
    if pending.phase == .sending { return pending }
    let shown = services(of: worktree).shownPullRequest
    if pending.wasAccepted {
      // Its hold lasts until the list reads it; another or none shown, as
      // after a checkout, says nothing of it.
      guard let shown, shown.url == pending.pullRequestURL else { return pending }
      guard shown.state == .open else { return nil }
      return pending.waitsForChecks && shown.autoMergesWhenReady ? nil : pending
    }
    guard let shown, shown.url == pending.pullRequestURL, shown.state == .open else { return nil }
    guard shown.headCommit == pending.headCommit else { return nil }
    let readiness = mergeReadiness(of: shown, in: worktree)
    var current = pending
    switch readiness.mergeAction {
    case .merge:
      current.waitsForChecks = false

    case .mergeWhenReady:
      current.waitsForChecks = true

    case .cancelAutoMerge:
      return nil

    case nil:
      // Checks not yet read for this head: the form waits, or not, as it did.
      guard readiness.awaitsChecksRead else { return nil }
    }
    return current
  }

  private func editMergeMessage(
    of worktree: Worktree,
    _ edit: (inout PullRequestMergeMessage) -> Void,
  ) {
    guard var pending = pendingMerge(of: worktree), pending.isEditable, let method = pending.method,
      var message = pending.message
    else { return }
    edit(&message)
    pending.edits[method] = message
    remoteState.pendingMerges[worktree.id] = pending
  }
}
