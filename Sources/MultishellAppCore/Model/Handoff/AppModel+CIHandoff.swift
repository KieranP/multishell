import Foundation
import MultishellCore
import MultishellServices

extension AppModel {
  /// The newest run's failures the CI page can send: earlier runs are history.
  func ciHandoffItems(of run: CIRun) -> [CIHandoffItem] {
    ciWorkflowListing(of: run, sendsFailures: true).items
  }

  /// What the page lists of `run`, read once per draw; only the newest run's
  /// failures can be sent, earlier runs being history.
  public func ciWorkflowListing(of run: CIRun, sendsFailures: Bool) -> CIWorkflowListing {
    let workflows = ciWorkflows(ofRun: run)
    // Before its workflows read, the whole report would be one Run output, sent
    // again as jobs once they land.
    return CIWorkflowListing(
      run: run,
      workflows: workflows ?? [],
      report: failureReport(of: run),
      sendsFailures: sendsFailures && workflows != nil,
    )
  }

  /// `nil` where the newest run has nothing to send and nothing was sent from it;
  /// over the items the page already built for its rows.
  public func ciHandoffFooter(
    of worktree: Worktree,
    over listing: CIWorkflowListing,
  ) -> HandoffFooter? {
    handoffFooter(on: .ciRuns, of: listing.candidates, in: worktree)
  }

  /// The newest run's checked failures written to one file and mentioned in the
  /// prompt of the pane named, else the picker's, then marked sent.
  @discardableResult
  public func sendCIFailures(
    of worktreeID: Worktree.ID,
    to sessionID: TerminalSession.ID?,
    takingFocus: Bool,
  ) -> HandoffSendOutcome {
    guard let worktree = workspace.worktree(worktreeID), case .run(let run) = ciPage(of: worktree)
    else { return .noPage }
    // Each Send says only its own outcome, not the last one's.
    noteHandoffMiss(nil, on: .ciRuns, in: worktreeID)
    let choices = handoff.choices[worktreeID] ?? HandoffChoices()
    let items = ciHandoffItems(of: run).filter { choices.state(of: $0.candidate).isChecked }
    guard !items.isEmpty else { return .nothingChecked }
    guard let recipient = handoffRecipientNotingMiss(named: sessionID, on: .ciRuns, in: worktreeID)
    else {
      return .noRecipient
    }
    let provider = ciProviderName(of: worktree) ?? ""
    let document = AgentHandoff.document(
      introduction: CIHandoff.introduction(provider: provider),
      entries: CIHandoff.entries(
        of: items,
        run: run,
        provider: provider,
        localTip: services(of: worktree).localTip,
      ),
    )
    let delivery = deliverHandoff(
      document,
      named: CIHandoff.fileName(forWorktreeNamed: workspace.displayName(of: worktree)),
      sentence: { t("handoff.ci-sentence", $0) },
      to: recipient,
      takingFocus: takingFocus,
    )
    if let missed = outcomeNotingMiss(of: delivery, to: recipient, on: .ciRuns, in: worktreeID) {
      return missed
    }
    let jobCount = items.count { $0.job != nil }
    let count =
      jobCount == items.count ? t("count.jobs", jobCount) : t("count.failures", items.count)
    markHandoffItemsSent(
      items.map(\.candidate.id),
      on: .ciRuns,
      in: worktreeID,
      to: recipient.agentName,
      summary: t("handoff.sent-summary", count, recipient.agentName),
    )
    return .sent(itemCount: items.count, to: recipient)
  }
}
