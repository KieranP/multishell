import MultishellAppCore
import MultishellCore
import SwiftUI

/// Create Pull Request on the pull request page and the row's popover, where
/// the model offers it: a branch with none, or one whose pull request closed.
struct CreatePullRequestButton: View {
  let model: AppModel
  let worktree: Worktree

  var body: some View {
    if let item = model.pullRequestMenuItem(for: worktree), case .create(let isPublishing) = item {
      Button(item.title) {
        Task { await model.createPullRequest(for: worktree) }
      }
      .disabled(isPublishing)
    }
  }
}
