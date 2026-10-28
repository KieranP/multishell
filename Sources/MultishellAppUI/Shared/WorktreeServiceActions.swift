import MultishellAppCore
import MultishellCore
import SwiftUI

/// The actions menu's pull request and CI items, under a divider of their own
/// where there are any.
struct WorktreeServiceActions: View {
  let model: AppModel
  let worktree: Worktree

  var body: some View {
    let pullRequestItem = model.pullRequestMenuItem(for: worktree)
    let ciIntegration = model.ciMenuIntegration(for: worktree)
    if pullRequestItem != nil || ciIntegration != nil { Divider() }
    if let item = pullRequestItem {
      Button(item.title) {
        Task {
          switch item {
          case .create: await model.createPullRequest(for: worktree)
          case .open: await model.openPullRequest(of: worktree)
          }
        }
      }
      .disabled(item == .create(isPublishing: true))
    }
    if let ciIntegration {
      Button(t("action.open-ci", ciIntegration.displayName)) {
        Task { await model.openCIRuns(of: worktree) }
      }
    }
  }
}
