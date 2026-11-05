import MultishellCore

/// The Global column of a project's settings table where `inherited` alone
/// cannot word it: a detected value, or one worded as its menu words it.
extension AppModel {
  /// Worded as the All Projects menu lists the choice, so the two read alike.
  public var globalShellValue: OverrideGlobalValue {
    let id = globalShellID
    let label = shellDetection.options(selected: id).label(of: id)
    return globalValue(label ?? shellDisplayName(id), setIn: .terminal)
  }

  public var globalAgentValue: OverrideGlobalValue {
    let id = globalAgentID
    let label = agentDetection.options(selected: id).label(of: id)
    return globalValue(label ?? agentDisplayName(id), setIn: .agentSettings)
  }

  /// The global flags of the agent this project runs, which may be its own.
  /// Agent settings edits the global agent's flags alone, so only those open it.
  public func globalAgentFlagsValue(for project: Project) -> OverrideGlobalValue {
    let editsTheseFlags =
      hasPreferredAgent && !usesCustomAgent
      && workspace.effectiveAgentID(for: project) == workspace.preferredAgentID
    return globalValue(
      workspace.globalAgentFlags(for: project),
      setIn: editsTheseFlags ? .agentSettings : nil,
    )
  }

  /// The repository file's branch, else what detection finds with the override
  /// set aside, there being no global to follow.
  public func defaultBranchGlobalValue(for project: Project) -> OverrideGlobalValue {
    let inherited = inherited(.defaultBranch, global: "", for: project)
    if inherited.isFromRepository { return inherited.globalValue(inherited.value, setIn: nil) }
    return OverrideGlobalValue(
      text: detectedDefaultBranchText(for: project),
      blankWord: t("inherited.none"),
      source: .detected,
      settingsSection: nil,
    )
  }

  private func detectedDefaultBranchText(for project: Project) -> String {
    switch defaultBranchProgress(of: project) {
    case .unscannable: t("inherited.not-detected")
    case .awaitingScan: t("inherited.detecting")

    case .scanned:
      detectedDefaultBranchNames[project.id].map { t("inherited.detected", $0) }
        ?? t("inherited.not-detected")
    }
  }

  private func globalValue(_ text: String, setIn section: SettingsSection?) -> OverrideGlobalValue {
    OverrideGlobalValue(
      text: text,
      blankWord: t("inherited.none"),
      source: .global,
      settingsSection: section,
    )
  }
}
