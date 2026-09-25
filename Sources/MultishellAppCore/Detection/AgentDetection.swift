import Foundation
import MultishellCore
import MultishellProcess

/// Which catalogue agents are on a PATH, and how the dropdown lists them.
public struct AgentDetection: Equatable, Sendable {
  /// Agent id to the executable found for it.
  let found: [String: URL]

  static let empty = AgentDetection(found: [:])

  init(found: [String: URL]) {
    self.found = found
  }

  init(searchPath: String?) {
    var found: [String: URL] = [:]
    for agent in AgentCatalogue.agents {
      if let executable = ExecutableLookup.find(agent.executable, searchPath: searchPath) {
        found[agent.id] = executable
      }
    }
    self.found = found
  }

  func isInstalled(_ id: String) -> Bool {
    id == AgentCatalogue.customID || found[id] != nil
  }

  public func options(selected: String?) -> [DetectionOption] {
    DetectionOption.catalogueOptions(
      AgentCatalogue.agents.map { ($0.id, $0.name) },
      installed: { found[$0] != nil },
      selected: selected,
      noneID: AgentCatalogue.noneID,
      customID: AgentCatalogue.customID)
  }
}
