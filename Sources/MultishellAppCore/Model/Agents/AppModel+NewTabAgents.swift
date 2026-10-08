import Foundation
import MultishellCore

extension AppModel {
  /// "New Claude Code Tab", and the typed command by its own name rather
  /// than as "New Custom command Tab".
  public func newAgentTabMenuLabel(_ id: String) -> String {
    id == AgentCatalogue.customID
      ? t("tab.new-custom-agent") : t("tab.new-named-agent", agentDisplayName(id))
  }

  /// What a New Tab menu offers: the PATH scan's finds in catalogue order,
  /// then the custom command once typed. Run on either changing, never from a view.
  func refreshNewTabAgents() {
    var ids = AgentCatalogue.agents.map(\.id).filter(agentDetection.isInstalled)
    if !workspace.customAgentCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      ids.append(AgentCatalogue.customID)
    }
    setIfChanged(\.newTabAgentIDs, ids)
  }
}
