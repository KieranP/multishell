import Foundation
import MultishellCore

/// One agent's line in Settings > Agents: whether its hooks are in place,
/// and what the row says about them.
///
/// An agent is listed once it is on the login shell's PATH, and stays
/// listed while its hooks are installed, so hooks left behind by an agent
/// since uninstalled can still be taken out.
public struct AgentHooksRow: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  /// The file the hooks go in, as the row names it.
  public let path: String
  public let isInstalled: Bool
  /// What the disclosure button offers to show: the file is JSON for every
  /// agent but OpenCode, which is given a plugin.
  public let contentsName: String
  public let info: String

  public static func rows(
    detection: AgentDetection, installed: Set<String>,
    integrations: [AgentHookIntegration] = AgentHooks.integrations
  ) -> [AgentHooksRow] {
    integrations.compactMap { integration in
      let isInstalled = installed.contains(integration.id)
      guard isInstalled || detection.isInstalled(integration.id) else { return nil }
      return AgentHooksRow(
        id: integration.id,
        name: integration.name,
        path: integration.displayPath,
        isInstalled: isInstalled,
        contentsName: integration.isPlugin
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
