import Foundation
import MultishellCore
import MultishellServices

extension AppModel {
  /// What Send carries: the checked items of those read, `nil` checks where
  /// `pr send` asked for threads alone.
  private func itemsToSend(
    of pullRequest: PullRequest,
    in worktree: Worktree,
    checks: PullRequestChecks?,
    threads: [PullRequestThread],
  ) -> [PullRequestHandoffItem] {
    PullRequestHandoffItem.items(
      checks: checks?.checks,
      headCommit: checks?.headCommit ?? pullRequest.headCommit,
      threads: threads,
    )
    .filter { handoffState(of: $0.candidate, in: worktree.id).isChecked }
  }

  /// Why a Send with nothing to carry sent nothing: a failed read, said over the
  /// foot, checks first, else nothing checked.
  private func outcomeSendingNothing(
    checks: Result<PullRequestChecks?, ServiceReadFailure>,
    threads: Result<[PullRequestThread], ServiceReadFailure>,
    integration: ServiceIntegration,
    in worktreeID: Worktree.ID,
  ) -> HandoffSendOutcome {
    if case .failure(let failure) = checks {
      let reason = failure.reason(integration: integration)
      noteHandoffMiss(t("panel.checks-not-read", reason), on: .pullRequest, in: worktreeID)
      return .checksNotRead(reason: reason)
    }
    if case .failure(let failure) = threads {
      let reason = failure.reason(integration: integration)
      noteHandoffMiss(t("panel.threads-not-read", reason), on: .pullRequest, in: worktreeID)
      return .threadsNotRead(reason: reason)
    }
    return .nothingChecked
  }

  /// What a step lists that Send can carry, from the threads the page read once.
  public func mergePathStepItems(
    of step: MergePath.Step,
    in path: MergePath,
    on pullRequest: PullRequest,
    threads: [PullRequestThread],
  ) -> MergePathStepItems {
    MergePathStepItems(of: step, in: path, headCommit: pullRequest.headCommit, threads: threads)
  }

  /// A step's hint, and while its list is collapsed how much it would send.
  public func mergePathHint(
    of step: MergePath.Step,
    in path: MergePath,
    base: String,
    host: String,
    items: MergePathStepItems,
    isCollapsed: Bool,
    in worktreeID: Worktree.ID,
  ) -> String? {
    let parts = [
      path.hint(of: step, base: base, host: host),
      handoffToSendText(of: items.candidates, isCollapsed: isCollapsed, in: worktreeID),
    ]
    let hint = parts.compactMap(\.self)
    return hint.isEmpty ? nil : hint.joined(separator: ". ")
  }

  /// `nil` with nothing to send and nothing sent from the page; from the path
  /// the page already drew, so its checks are not weighed again.
  public func pullRequestHandoffFooter(
    of worktree: Worktree,
    along path: MergePath,
    on pullRequest: PullRequest,
    threads: [PullRequestThread],
  ) -> HandoffFooter? {
    // Claimed before its own reads, so a second click finds Send off rather than nothing.
    switch handoff.sendPhases[worktree.id] {
    case .readingLogs(let count): return .reading(t("count.reading-logs", count))
    case .preparing: return .reading(t("handoff.preparing"))
    case nil: break
    }
    let items = PullRequestHandoffItem.items(
      checks: path.checks,
      headCommit: pullRequest.headCommit,
      threads: threads,
    )
    return handoffFooter(on: .pullRequest, of: items.map(\.candidate), in: worktree)
  }

  /// The checked items, failing checks' logs read first, sent to the pane named,
  /// else the picker's, or nowhere; see Docs/design/services/send-feedback.md.
  @discardableResult
  public func sendPullRequestFeedback(
    of worktreeID: Worktree.ID,
    to sessionID: TerminalSession.ID?,
    takingFocus: Bool,
    includesChecks: Bool = true,
    includesThreads: Bool = true,
  ) async -> HandoffSendOutcome {
    guard let worktree = workspace.worktree(worktreeID),
      let project = workspace.project(worktree.projectID),
      let service = pullRequestHost(for: project),
      case .pullRequest(let pullRequest) = pullRequestPage(of: worktree)
    else { return .noPage }
    let (integration, host) = service
    // Each Send says only its own outcome, not the last one's.
    noteHandoffMiss(nil, on: .pullRequest, in: worktreeID)
    // Claimed before any read, so a second click cannot read the same logs again.
    if includesChecks {
      guard handoff.sendPhases[worktreeID] == nil else { return .alreadySending }
      handoff.sendPhases[worktreeID] = .preparing
    }
    defer { if includesChecks { handoff.sendPhases[worktreeID] = nil } }
    async let checksRead: Result<PullRequestChecks?, ServiceReadFailure> =
      includesChecks
      ? checksToSend(of: pullRequest, in: worktree, with: host).map(Optional.some)
      : .success(nil)
    async let threadsRead: Result<[PullRequestThread], ServiceReadFailure> =
      includesThreads ? threadsToSend(of: pullRequest, in: worktree, with: host) : .success([])
    let (checks, threads) = await (checksRead, threadsRead)
    let items = itemsToSend(
      of: pullRequest,
      in: worktree,
      checks: (try? checks.get()) ?? nil,
      threads: (try? threads.get()) ?? [],
    )
    guard !items.isEmpty else {
      return outcomeSendingNothing(
        checks: checks,
        threads: threads,
        integration: integration,
        in: worktreeID,
      )
    }
    guard
      let named = handoffRecipientNotingMiss(named: sessionID, on: .pullRequest, in: worktreeID)
    else {
      return .noRecipient
    }
    let logs = await readFailedLogs(of: items, on: pullRequest, via: service, in: worktree)
    // A script's Ctrl-C during the reads means the paste is no longer wanted.
    guard !Task.isCancelled else { return .cancelled }
    guard let recipient = handoffRecipient(id: named.id, in: worktreeID) else {
      noteHandoffMiss(
        t("handoff.gone-while-reading", named.agentName),
        on: .pullRequest,
        in: worktreeID,
      )
      return .noRecipient
    }
    // A box unchecked, or an item sent, while the logs read is the user's last word.
    let sending = items.filter { handoffState(of: $0.candidate, in: worktreeID).isChecked }
    guard !sending.isEmpty else { return .nothingChecked }
    return deliverPullRequestHandoff(
      of: sending,
      logs: logs,
      on: pullRequest,
      in: worktree,
      to: recipient,
      takingFocus: takingFocus,
    )
  }

  /// The note written and pasted, then each item marked sent.
  private func deliverPullRequestHandoff(
    of items: [PullRequestHandoffItem],
    logs: [HandoffItemID: CheckLogRead],
    on pullRequest: PullRequest,
    in worktree: Worktree,
    to recipient: HandoffRecipient,
    takingFocus: Bool,
  ) -> HandoffSendOutcome {
    let document = AgentHandoff.document(
      introduction: PullRequestHandoff.introduction(number: pullRequest.number),
      entries: PullRequestHandoff.entries(
        of: items,
        logs: logs,
        localTip: services(of: worktree).localTip,
      ),
    )
    let delivery = deliverHandoff(
      document,
      named: PullRequestHandoff.fileName(
        number: pullRequest.number,
        forWorktreeNamed: workspace.displayName(of: worktree),
      ),
      sentence: { t("handoff.pull-request-sentence", $0) },
      to: recipient,
      takingFocus: takingFocus,
    )
    if let missed = outcomeNotingMiss(
      of: delivery,
      to: recipient,
      on: .pullRequest,
      in: worktree.id,
    ) {
      return missed
    }
    markHandoffItemsSent(
      items.map(\.candidate.id),
      on: .pullRequest,
      in: worktree.id,
      to: recipient.agentName,
      summary: t("handoff.sent-summary", t("count.items", items.count), recipient.agentName),
    )
    return .sent(itemCount: items.count, to: recipient)
  }

  /// The checked failing checks' logs the host can read, a few at a time; Send is
  /// off while they read, and a check from another CI goes without one.
  private func readFailedLogs(
    of items: [PullRequestHandoffItem],
    on pullRequest: PullRequest,
    via service: (ServiceIntegration, any PullRequestHost),
    in worktree: Worktree,
  ) async -> [HandoffItemID: CheckLogRead] {
    let (integration, host) = service
    let checks = items.compactMap { item -> (HandoffItemID, PullRequestCheck)? in
      guard case .check(let check, _) = item, host.readsFailedLog(of: check, on: pullRequest)
      else { return nil }
      return (item.candidate.id, check)
    }
    guard !checks.isEmpty else { return [:] }
    setIfChanged(\.handoff.sendPhases[worktree.id], .readingLogs(count: checks.count))
    defer { setIfChanged(\.handoff.sendPhases[worktree.id], .preparing) }
    let directory = worktree.path
    let lineLimit = HandoffLogTail.linesToRead
    let logs = await checks.mapConcurrentlyUnordered(width: Self.concurrentServiceReads) {
      item -> (HandoffItemID, CheckLogRead) in
      let (id, check) = item
      do {
        let log = try await host.failedLog(
          of: check,
          on: pullRequest,
          keepingLast: lineLimit,
          in: directory,
        )
        return (id, log.map(CheckLogRead.read) ?? .noLog)
      } catch {
        return (id, .failed(ServiceReadFailure(error).reason(integration: integration)))
      }
    }
    return Dictionary(keepingFirst: logs)
  }
}
