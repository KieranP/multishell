import Foundation
import MultishellCore
import MultishellProcess

/// Which catalogue agents are on a PATH, and how the dropdown lists them.
public struct AgentDetection: Equatable, Sendable {
  /// Agent id to the executable found for it.
  public let found: [String: URL]

  public static let empty = AgentDetection(found: [:])

  public init(found: [String: URL]) {
    self.found = found
  }

  public init(path: String?) {
    var found: [String: URL] = [:]
    for agent in AgentCatalogue.agents {
      if let executable = ExecutableLookup.find(agent.executable, path: path) {
        found[agent.id] = executable
      }
    }
    self.found = found
  }

  public func isInstalled(_ id: String) -> Bool {
    id == AgentCatalogue.customID || found[id] != nil
  }

  public func options(selected: String?) -> [DetectionOption] {
    DetectionOption.catalogue(
      AgentCatalogue.agents.map { ($0.id, $0.name) },
      installed: { found[$0] != nil },
      selected: selected,
      noneID: AgentCatalogue.noneID,
      customID: AgentCatalogue.customID)
  }
}
