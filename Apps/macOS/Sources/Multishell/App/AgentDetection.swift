import Foundation
import MultishellCore
import MultishellProcess

/// Which catalogue agents are on a PATH, and how the dropdown lists them.
///
/// A SwiftUI picker whose selection is not in its list shows blank, so a
/// stored id that is no longer installed is listed, marked as such, rather
/// than dropped.
struct AgentDetection: Equatable {
  struct Option: Identifiable, Equatable {
    let id: String
    let label: String
    let isInstalled: Bool
  }

  /// Agent id to the executable found for it.
  let found: [String: URL]

  static let empty = AgentDetection(found: [:])

  init(found: [String: URL]) {
    self.found = found
  }

  init(path: String?) {
    var found: [String: URL] = [:]
    for agent in AgentCatalogue.agents {
      if let executable = ExecutableLookup.find(agent.executable, path: path) {
        found[agent.id] = executable
      }
    }
    self.found = found
  }

  var isClaudeCodeInstalled: Bool { found[AgentCatalogue.claudeID] != nil }

  func isInstalled(_ id: String) -> Bool {
    id == AgentCatalogue.customID || found[id] != nil
  }

  /// None, the installed agents in catalogue order, the selected one if it
  /// is not installed, then Custom.
  func options(selected: String?) -> [Option] {
    var options = [Option(id: AgentCatalogue.noneID, label: "None", isInstalled: true)]
    for agent in AgentCatalogue.agents {
      if let _ = found[agent.id] {
        options.append(Option(id: agent.id, label: agent.name, isInstalled: true))
      } else if agent.id == selected {
        options.append(
          Option(id: agent.id, label: "\(agent.name) (not installed)", isInstalled: false))
      }
    }
    if let selected, selected != AgentCatalogue.noneID, selected != AgentCatalogue.customID,
      AgentCatalogue.agent(selected) == nil
    {
      options.append(Option(id: selected, label: "\(selected) (not installed)", isInstalled: false))
    }
    options.append(Option(id: AgentCatalogue.customID, label: "Custom command…", isInstalled: true))
    return options
  }
}
