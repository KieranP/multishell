import MultishellCore

extension AppModel {
  /// Whether what the file asks for is in force for this project.
  public func trustsSharedSettings(of project: Project) -> Bool {
    guard let shared = project.sharedSettings.confined else { return false }
    return project.settings.trustsSharedSettings(of: shared)
  }

  /// Asked when the user turns to the project, not when a refresh finds the
  /// file: a launch would otherwise open with a queue of questions.
  func askAboutSharedSettingsIfNeeded(for id: Project.ID) {
    // Never over the new-worktree sheet or its create: two on one window
    // fight, and the question returns on the next selection.
    guard newWorktreeRequest == nil, worktreeCreationStep == nil else { return }
    guard pendingSharedSettingsTrust == nil, let project = workspace.project(id),
      let shared = project.sharedSettings.confined,
      let trustCoveredText = shared.trustCoveredText, let digest = shared.digest,
      project.settings.needsTrustDecision(for: shared)
    else { return }
    pendingSharedSettingsTrust = PendingSharedSettingsTrust(
      projectID: id, projectName: project.name, trustCoveredText: trustCoveredText,
      digest: digest)
  }

  /// Stores an answer against the file's sha256. The project is read again,
  /// a settings window outliving the refresh that replaced its record.
  func recordTrustDecision(digest: String, trusted: Bool, for id: Project.ID) {
    guard var settings = workspace.project(id)?.settings else { return }
    settings.recordTrustDecision(digest: digest, trusted: trusted)
    store.updateSettings(settings, forProject: id)
  }

  /// The dialog's answer. Either way the question is not asked again for
  /// this file, this branch's or another's.
  public func decideSharedSettings(_ pending: PendingSharedSettingsTrust, trusted: Bool) {
    recordTrustDecision(digest: pending.digest, trusted: trusted, for: pending.projectID)
    // The whole value, not its project: a different question that arrived
    // while this one stood is not answered by it.
    if pendingSharedSettingsTrust == pending { pendingSharedSettingsTrust = nil }
  }

  /// From the project's Hooks tab: trust what the file currently asks for,
  /// or stop.
  public func setTrustsSharedSettings(_ trusted: Bool, for project: Project) {
    // A button's action runs after the render that built it, so this one
    // copy can be a read behind; the digest decides what trust is stored.
    let project = workspace.project(project.id) ?? project
    guard let shared = project.sharedSettings.confined, shared.asksForTrust,
      let digest = shared.digest
    else { return }
    recordTrustDecision(digest: digest, trusted: trusted, for: project.id)
    dismissSharedSettingsTrust(for: project.id)
  }

  func dismissSharedSettingsTrust(for id: Project.ID) {
    if pendingSharedSettingsTrust?.projectID == id { pendingSharedSettingsTrust = nil }
  }
}
