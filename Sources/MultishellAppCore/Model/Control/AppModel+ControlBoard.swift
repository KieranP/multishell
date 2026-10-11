import MultishellCore

extension AppModel {
  /// The board as built for drawing, whether or not it is on screen.
  func replyToListBoard() -> ControlReply {
    .json(
      BoardListing(
        showsAllTerminals: showsAllTerminals,
        columns: agentBoard.columns.map { column in
          BoardListing.Column(
            lane: column.lane.rawValue,
            cards: column.cards.map { card in
              BoardListing.Card(
                pane: card.id,
                tab: card.tabID,
                worktree: ControlID.worktree(card.worktreeID),
                title: card.title,
                agent: card.occupant.agentID,
                project: workspace.worktree(card.worktreeID).map { worktree in
                  ControlID.project(worktree.projectID)
                },
                projectName: card.projectName,
                worktreeName: card.worktreeName,
                state: card.state,
                workerCount: card.workers.count,
              )
            },
          )
        },
      )
    )
  }
}
