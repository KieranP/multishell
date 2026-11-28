import MultishellCore

/// An action waiting on its session's first launch, with the project it was
/// picked under: two projects may list the session's worktree path.
struct PendingActionRun {
  let action: ProjectAction
  let projectID: Project.ID
}
