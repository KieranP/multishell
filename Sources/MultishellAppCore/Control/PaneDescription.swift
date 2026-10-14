import Foundation
import MultishellCore

/// What `multishell panes show` prints: one pane, where it sits, and the
/// state a script waits on.
struct PaneDescription: Encodable, Equatable {
  /// One worker the agent reported, by the agent's own id for it.
  struct WorkerRecord: Encodable, Equatable {
    let id: String
    let type: String?
    let name: String?
    let description: String?
    /// The worker that launched it, `nil` for the agent's own.
    let parent: String?
    let startedAt: Date?

    init(_ worker: Worker) {
      id = worker.id
      type = worker.type
      name = worker.name
      description = worker.description
      parent = worker.parentID
      startedAt = worker.startedAt
    }
  }

  /// Its find bar, as the engine last counted its matches.
  struct Find: Encodable, Equatable {
    let text: String
    /// `nil` until the engine has counted.
    let total: Int?
    /// Which match is selected, from 0; `nil` before a step.
    let selected: Int?
  }

  let id: TerminalSession.ID
  let tab: TerminalTab.ID
  /// Its worktree's `ControlID`.
  let worktree: String
  let title: String
  let isLive: Bool
  let isFocused: Bool
  let agent: String?
  /// The pane's own dot, `nil` for none.
  let state: SessionState?
  /// What its agent has out, oldest first, as its chip lists them.
  let workers: [WorkerRecord]
  /// `nil` while its find bar is down.
  let find: Find?
}
