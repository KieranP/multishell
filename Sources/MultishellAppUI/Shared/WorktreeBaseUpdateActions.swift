import MultishellAppCore
import MultishellCore
import SwiftUI

/// The actions menu's Merge from and Rebase onto the base, or, with one stopped
/// on conflicts, Send Conflicts To and Abort, under a divider of their own.
struct WorktreeBaseUpdateActions: View {
  let model: AppModel
  let worktree: Worktree

  var body: some View {
    switch model.baseUpdateMenu(for: worktree) {
    case .update(let base, let isRunning):
      Divider()
      Button(t("action.merge-from-base", base)) {
        Task { await model.requestBaseUpdate(of: worktree, by: .merge) }
      }
      .disabled(isRunning)
      Button(t("action.rebase-onto-base", base)) {
        Task { await model.requestBaseUpdate(of: worktree, by: .rebase) }
      }
      .disabled(isRunning)

    case .unfinished(let method, let sendTargets, let isRunning):
      Divider()
      if let sendTargets {
        Menu(t("action.send-conflicts-to")) {
          ForEach(sendTargets.recipients) { recipient in
            Button(t("action.conflicts-recipient", recipient.tabTitle, recipient.agentName)) {
              Task { await model.sendConflicts(of: worktree, to: recipient.id) }
            }
          }
          if !sendTargets.recipients.isEmpty { Divider() }
          Button(t("menu.new-agent-tab")) {
            Task { await model.sendConflictsToNewAgentTab(of: worktree) }
          }
          .disabled(!sendTargets.opensAgentTab)
        }
        .disabled(isRunning)
      }
      Button(method.abortLabel) {
        Task { await model.abortBaseUpdate(of: worktree, method: method) }
      }
      .disabled(isRunning)

    case nil:
      EmptyView()
    }
  }
}
