import MultishellCore

/// One agent's line in Settings > Agents. Listed once it is on the PATH, and
/// while its hooks are installed, so leftovers can still be taken out.
public struct AgentHooksRow: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  /// The file the hooks go in, as the row names it.
  public let displayPath: String
  public let isInstalled: Bool
  /// Installed by an older build and not what this one writes, so Add would
  /// write something else: offered as an update.
  public let wantsUpdate: Bool
  /// What the disclosure button offers to show: the file is JSON for every
  /// agent but OpenCode, which is given a plugin.
  public let contentsLabel: String
  public let info: String

  static func rows(
    detection: AgentDetection, installed: Set<String>, stale: Set<String> = [],
    integrations: [AgentHookIntegration] = AgentHookCatalogue.integrations
  ) -> [AgentHooksRow] {
    integrations.compactMap { integration in
      let isInstalled = installed.contains(integration.id)
      guard isInstalled || detection.isInstalled(integration.id) else { return nil }
      return AgentHooksRow(
        id: integration.id,
        name: integration.name,
        displayPath: integration.displayPath,
        isInstalled: isInstalled,
        wantsUpdate: isInstalled && stale.contains(integration.id),
        contentsLabel: integration.isPlugin
          ? t("agent-hooks.plugin") : t("agent-hooks.json"),
        info: info(for: integration))
    }
  }

  private static func info(for integration: AgentHookIntegration) -> String {
    var sentences = [t("agent-hooks.reports", integration.name)]
    if integration.isOursAlone {
      sentences.append(t("agent-hooks.ours-alone", integration.displayPath))
    } else {
      sentences.append(t("agent-hooks.shared", integration.displayPath))
    }
    if let note = integration.trustNote { sentences.append(note) }
    return sentences.joined(separator: " ")
  }
}
