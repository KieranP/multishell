import MultishellCore

extension AgentDetection {
  /// Rename agent's rows: the project's agent, then the catalogue's as the agent
  /// picker lists them, with no custom command.
  func renameOptions(selected: String?, unsetID: String) -> [DetectionOption] {
    [DetectionOption(id: unsetID, label: t("option.project-agent"))]
      + DetectionOption.installedOrSelectedOptions(
        AgentCatalogue.agents.map { ($0.id, $0.name) },
        isInstalled: isInstalled,
        selected: selected,
        reserved: [unsetID],
      )
  }
}
