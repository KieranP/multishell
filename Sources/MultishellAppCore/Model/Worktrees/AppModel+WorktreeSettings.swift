import MultishellCore

extension AppModel {
  public func setConfirmsWorktreeRemoval(_ enabled: Bool) {
    store.setConfirmsWorktreeRemoval(enabled)
  }

  public func setDeletesBranchWithWorktree(_ enabled: Bool) {
    store.setDeletesBranchWithWorktree(enabled)
  }

  public func setTrashesRemovedWorktrees(_ enabled: Bool) {
    store.setTrashesRemovedWorktrees(enabled)
  }

  public func setProjectHookTimeoutSeconds(_ seconds: Int) {
    store.setProjectHookTimeoutSeconds(seconds)
  }

  public func setWorktreeDefaults(_ defaults: WorktreeSettings) {
    store.setWorktreeDefaults(defaults)
  }
}
