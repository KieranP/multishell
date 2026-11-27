import Foundation
import MultishellCore
import MultishellProcess

/// What `config global` and `config project` take for a picker's key: what
/// the picker could hold, so neither stores what the other refuses.
extension AppModel {
  /// An agent the picker lists, None and Custom included.
  static func isAgentChoice(_ id: String) -> Bool {
    AgentCatalogue.startableIDs.contains(id) || id == AgentCatalogue.noneID
  }

  /// A shell the picker could hold: an executable named by its whole path, as
  /// the picker stores one, or the login or custom entry.
  func isShellChoice(_ id: String) -> Bool {
    [ShellChoice.loginShellID, ShellChoice.customID].contains(id)
      || (id.hasPrefix("/") && FileManager.default.isRunnableFile(atPath: id))
  }
}
