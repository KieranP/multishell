import MultishellCore

/// The Actions page's keys cell: recording a row's keys, and saying why keys
/// pressed were not taken, as the Shortcuts page does for a command.
extension AppModel {
  /// The recording a row shows, `nil` for every row but the one recording.
  public func actionKeysRecording(
    forAction name: String,
    in project: Project,
  ) -> ActionKeysRecording? {
    guard let recording = recordingActionKeys,
      recording.projectID == project.id, recording.actionName == name
    else { return nil }
    return recording
  }

  /// A refusal while recording; the pane's warning only once it ends, as the
  /// recorder stands where the keys were.
  public func actionKeysNote(forAction name: String, in project: Project) -> ActionKeysNote? {
    if let recording = actionKeysRecording(forAction: name, in: project) {
      return recording.refusal.map(ActionKeysNote.refusal)
    }
    return actionKeysWarning(forAction: name, in: project).map(ActionKeysNote.warning)
  }

  public func startRecordingActionKeys(forAction name: String, in project: Project) {
    recordingActionKeys = ActionKeysRecording(
      projectID: project.id,
      actionName: name,
      refusal: nil,
    )
  }

  /// Set where allowed, which ends the recording; otherwise it goes on, saying why.
  public func submitRecordedActionKeys(
    _ keys: KeyCombination,
    forAction name: String,
    in project: Project,
  ) {
    let refusal: ActionKeysRecording.Refusal? =
      switch setActionKeys(keys, forAction: name, in: project) {
      case .allowed: nil
      case .refused(let refusal): .refused(refusal)
      case .taken(let holder): .heldBy(keys, holder)
      }
    recordingActionKeys =
      refusal.map { ActionKeysRecording(projectID: project.id, actionName: name, refusal: $0) }
  }

  public func clearRecordedActionKeys(forAction name: String, in project: Project) {
    clearActionKeys(forAction: name, in: project)
    recordingActionKeys = nil
  }

  public func endActionKeysRecording() {
    recordingActionKeys = nil
  }

  /// A recording whose row has gone ends with it, or it came back live when
  /// the name did and took the next keys pressed.
  func settleActionKeysRecording() {
    guard let recording = recordingActionKeys else { return }
    let project = workspace.project(recording.projectID)
    let fileActions = project?.sharedSettingsSnapshot.confined?.actions ?? []
    let ownActions = project.map { ownSettings(of: $0).actions } ?? []
    let hasRow = (ownActions + fileActions).contains { $0.name == recording.actionName }
    if !hasRow { recordingActionKeys = nil }
  }
}
