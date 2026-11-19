import MultishellCore
import MultishellServices

extension AppModel {
  public func handoffState(
    of candidate: HandoffCandidate,
    in worktreeID: Worktree.ID,
  ) -> HandoffItemState {
    (handoff.choices[worktreeID] ?? HandoffChoices()).state(of: candidate)
  }

  public func handoffGroupState(
    of candidates: [HandoffCandidate],
    in worktreeID: Worktree.ID,
  ) -> HandoffGroupState? {
    (handoff.choices[worktreeID] ?? HandoffChoices()).groupState(of: candidates)
  }

  public func toggleHandoffItem(_ candidate: HandoffCandidate, in worktreeID: Worktree.ID) {
    updateHandoffChoices(in: worktreeID) { choices in
      choices.set(candidate.id, checked: !choices.state(of: candidate).isChecked)
    }
  }

  public func toggleHandoffGroup(_ candidates: [HandoffCandidate], in worktreeID: Worktree.ID) {
    updateHandoffChoices(in: worktreeID) { $0.toggleGroup(candidates) }
  }

  /// A click on the sent bubble, to send the item again.
  public func unmarkHandoffItemSent(_ id: HandoffItemID, in worktreeID: Worktree.ID) {
    updateHandoffChoices(in: worktreeID) { $0.unmarkSent(id) }
  }

  /// "1 to send" over a collapsed list, since Send carries its checked items unseen.
  public func handoffToSendText(
    of candidates: [HandoffCandidate],
    isCollapsed: Bool,
    in worktreeID: Worktree.ID,
  ) -> String? {
    guard isCollapsed else { return nil }
    let count = (handoff.choices[worktreeID] ?? HandoffChoices()).checked(among: candidates).count
    return count == 0 ? nil : t("count.to-send", count)
  }

  func markHandoffItemsSent(
    _ ids: [HandoffItemID],
    on page: ServicePage,
    in worktreeID: Worktree.ID,
    to agentName: String,
    summary: String,
  ) {
    updateHandoffChoices(in: worktreeID) { $0.markSent(ids, to: agentName) }
    var receipts = handoff.receipts[worktreeID] ?? [:]
    receipts[page] = summary
    setIfChanged(\.handoff.receipts[worktreeID], receipts)
  }

  /// After `page` read: what it no longer lists is let go, each read's kind only
  /// once that read answered, so an item whose details were dropped keeps its mark.
  func pruneHandoffChoices(of worktree: Worktree, after page: ServicePage) {
    guard handoff.choices[worktree.id] != nil else { return }
    for (source, listed) in listedHandoffItems(of: worktree, on: page) {
      updateHandoffChoices(in: worktree.id) { $0.keepOnly(listed, from: source) }
    }
  }

  /// Each read the page made that has answered, with what it lists.
  private func listedHandoffItems(
    of worktree: Worktree,
    on page: ServicePage,
  ) -> [HandoffItemSource: Set<HandoffItemID>] {
    switch page {
    case .pullRequest:
      guard case .pullRequest(let pullRequest) = pullRequestPage(of: worktree) else { return [:] }
      let checks = mergeReadiness(of: pullRequest, in: worktree).checks
      let threads = remoteState.threads[worktree.id]
      let items = PullRequestHandoffItem.items(
        checks: checks,
        headCommit: pullRequest.headCommit,
        threads: unresolvedThreads(of: pullRequest, in: worktree),
      )
      .map(\.candidate.id)
      var listed: [HandoffItemSource: Set<HandoffItemID>] = [:]
      if checks != nil { listed[.checks] = Set(items.filter { $0.source == .checks }) }
      if pullRequest.state.isSettled
        || (threads?.pullRequestNumber == pullRequest.number && threads?.threads != nil)
      {
        listed[.threads] = Set(items.filter { $0.source == .threads })
      }
      return listed

    case .ciRuns:
      guard case .run(let run) = ciPage(of: worktree), ciWorkflows(ofRun: run) != nil,
        run.status != .failed || failureReport(of: run) != nil
      else { return [:] }
      return [.ciRun: Set(ciHandoffItems(of: run).map(\.candidate.id))]
    }
  }

  private func updateHandoffChoices(
    in worktreeID: Worktree.ID,
    _ update: (inout HandoffChoices) -> Void,
  ) {
    var choices = handoff.choices[worktreeID] ?? HandoffChoices()
    update(&choices)
    setIfChanged(\.handoff.choices[worktreeID], choices)
  }
}
