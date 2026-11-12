import MultishellCore

@testable import MultishellAppCore

extension AppModel {
  /// As Review's Send does: to the agent its picker shows, taking the keyboard.
  @discardableResult
  func sendReviewToPickedAgent(of worktree: Worktree) -> Bool {
    guard case .ready(let picked, _, _) = reviewFooter(of: worktree) else { return false }
    return sendReview(of: worktree.id, to: picked.id, takingFocus: true)
  }
}
