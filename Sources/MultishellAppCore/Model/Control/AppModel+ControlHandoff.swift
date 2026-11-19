import Foundation
import MultishellCore
import MultishellServices

/// `multishell pr send` and `ci send`: the PR and CI pages' Send.
extension AppModel {
  func replyToSendPullRequestFeedback(
    in id: String?,
    to sessionID: UUID?,
    includesChecks: Bool,
    includesThreads: Bool,
  ) async -> ControlReply {
    await replyingInWorktree(id) { worktree in
      // As `panes paste`: the pane keeps whatever had the keyboard.
      let outcome = await sendPullRequestFeedback(
        of: worktree.id,
        to: sessionID,
        takingFocus: false,
        includesChecks: includesChecks,
        includesThreads: includesThreads,
      )
      return handoffReply(outcome, from: .pullRequest, in: worktree)
    }
  }

  func replyToSendCIFailures(in id: String?, to sessionID: UUID?) async -> ControlReply {
    await replyingInWorktree(id) { worktree in
      let outcome = sendCIFailures(of: worktree.id, to: sessionID, takingFocus: false)
      return handoffReply(outcome, from: .ciRuns, in: worktree)
    }
  }

  /// What the Send did, in the refusal a script can act on.
  private func handoffReply(
    _ outcome: HandoffSendOutcome,
    from page: ServicePage,
    in worktree: Worktree,
  ) -> ControlReply {
    let worktreeControlID = ControlID.worktree(worktree.id)
    switch outcome {
    case .alreadySending:
      return .refused(.handoffUnderWay(id: worktreeControlID))

    case .cancelled:
      // The helper hung up, so nothing reads the reply.
      return .done

    case .checksNotRead(let reason):
      return .refused(.checksNotRead(id: worktreeControlID, reason: reason))

    case .noPage:
      return .refused(.noServicePage(page, id: worktreeControlID))

    case .nothingChecked:
      return .refused(.nothingToHandOff(page, id: worktreeControlID))

    case .notPasted(let sessionID):
      return .refused(.paneNotLive(id: sessionID))

    case .noRecipient:
      return .refused(.noRecipient(id: worktreeControlID))

    case .notWritten:
      // The write's error was presented, and a request's alert is its answer.
      return .done

    case .threadsNotRead(let reason):
      return .refused(.threadsNotRead(id: worktreeControlID, reason: reason))

    case .sent(let itemCount, let recipient):
      return .json(
        HandoffReceipt(
          worktree: worktreeControlID,
          pane: recipient.id,
          agent: recipient.agentName,
          itemCount: itemCount,
        )
      )
    }
  }
}
