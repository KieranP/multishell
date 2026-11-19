import MultishellCore

/// What a page's Send foot shows: the picker and Send, the last Send's receipt,
/// or why there is nobody to send to.
extension AppModel {
  /// `nil` with nothing to send and nothing sent, so the page draws no foot. What
  /// the last Send said stays until an unsent item is checked or none it sent is listed.
  func handoffFooter(
    on page: ServicePage,
    of candidates: [HandoffCandidate],
    in worktree: Worktree,
  ) -> HandoffFooter? {
    let choices = handoff.choices[worktree.id] ?? HandoffChoices()
    let canSend = !choices.checked(among: candidates).isEmpty
    // A receipt speaks of items still listed; a newer run or push lists others.
    let listsASentItem = candidates.contains { choices.state(of: $0).isSent }
    if !canSend, listsASentItem, let receipt = handoff.receipts[worktree.id]?[page] {
      return .sent(summary: receipt)
    }
    guard !candidates.isEmpty else { return nil }
    return handoffPickerFooter(of: worktree, canSend: canSend)
  }

  /// A Send foot's picker and Send, on Review and the PR and CI pages alike, or why
  /// there is nobody to send to.
  func handoffPickerFooter(of worktree: Worktree, canSend: Bool) -> HandoffFooter {
    let recipients = handoffRecipients(in: worktree.id)
    guard let picked = handoffRecipient(from: recipients, in: worktree.id) else {
      return .noRecipient(t("handoff.no-agent", workspace.displayName(of: worktree)))
    }
    return .ready(picked: picked, recipients: recipients, canSend: canSend)
  }
}
