import Foundation
import MultishellCore
import MultishellGitKit

@testable import MultishellAppCore

extension AgentBoardCard {
  static func sample(
    occupant: Occupant,
    title: String = "claude",
    worktreeID: Worktree.ID = "/w",
    worktreeName: String = "main",
    state: SessionState? = nil,
    since: Date? = nil,
    note: SessionNote? = nil,
    status: WorktreeStatus? = nil,
  ) -> AgentBoardCard {
    AgentBoardCard(
      id: UUID(),
      tabID: UUID(),
      worktreeID: worktreeID,
      occupant: occupant,
      title: title,
      projectName: "multishell",
      worktreeName: worktreeName,
      state: state,
      since: since,
      note: note,
      status: status,
    )
  }
}
