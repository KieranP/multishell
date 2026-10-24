import MultishellCore

/// Settings > Agents' Rename agent, model and effort, app-wide and apart
/// from the agent new tabs start.
extension AppModel {
  /// The pickers' row for nothing chosen, which stores `nil`: the project's
  /// agent, or the agent's own model or effort.
  public static var renameUnsetID: String { "" }

  /// The project's agent first, then the catalogue's as the agent picker lists
  /// them, no custom command: Auto Rename runs only what the catalogue knows.
  public var renameAgentOptions: [DetectionOption] {
    agentDetection.renameOptions(
      selected: workspace.renameAgentID,
      unsetID: Self.renameUnsetID,
    )
  }

  /// The agent's own default alone with no Rename agent chosen, which runs at
  /// its own defaults.
  public var renameModelOptions: [DetectionOption] {
    Self.renameChoices(
      workspace.renameOneShot?.models.map(\.id) ?? [],
      keeping: workspace.renameModel,
      unsetLabel: t("option.agent-default-model"),
    )
  }

  /// The agent's own default alone where it takes no effort flag, or none is chosen.
  public var renameEffortOptions: [DetectionOption] {
    let oneShot = workspace.renameOneShot.flatMap { $0.takesEffort ? $0 : nil }
    return Self.renameChoices(
      oneShot?.efforts(forModel: workspace.renameModel) ?? [],
      keeping: workspace.renameEffort,
      unsetLabel: t("option.agent-default-effort"),
    )
  }

  /// Only with a Rename agent chosen; the default agent runs at its own.
  public var canChooseRenameModel: Bool {
    workspace.renameOneShot != nil
  }

  /// Only where the chosen Rename agent takes an effort flag, whatever is stored.
  public var canChooseRenameEffort: Bool {
    workspace.renameOneShot?.takesEffort == true
  }

  /// A stored value the catalogue no longer lists stays listed, or the picker
  /// shows blank; the run passes it nowhere.
  private static func renameChoices(
    _ ids: [String],
    keeping stored: String?,
    unsetLabel: String,
  ) -> [DetectionOption] {
    let kept = stored.map { ids.contains($0) ? [] : [$0] } ?? []
    return [DetectionOption(id: renameUnsetID, label: unsetLabel)]
      + (ids + kept).map { DetectionOption(id: $0, label: $0) }
  }

  public func setRenameAgent(_ id: String?) {
    store.setRenameAgent(id == Self.renameUnsetID ? nil : id)
  }

  public func setRenameModel(_ model: String?) {
    store.setRenameModel(model == Self.renameUnsetID ? nil : model)
  }

  public func setRenameEffort(_ effort: String?) {
    store.setRenameEffort(effort == Self.renameUnsetID ? nil : effort)
  }
}
