import MultishellCore

extension AppModel {
  public func setHookTimeoutSeconds(_ seconds: Int) {
    store.setHookTimeoutSeconds(seconds)
  }

  public func setWorktreeDefaults(_ defaults: WorktreeSettings) {
    store.setWorktreeDefaults(defaults)
  }
}
