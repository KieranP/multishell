import MultishellCore
import MultishellGitKit

/// How a merge or rebase the app ran ended, and the pane opened on its
/// conflicts where the project sends them to its agent.
struct BaseUpdateRun: Equatable {
  let outcome: BaseUpdateOutcome
  let conflictPane: TerminalSession.ID?
}
