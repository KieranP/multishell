import Foundation
import MultishellCore

extension AppModel {
  /// What the menu item or click for the view does. `project` names the one
  /// project settings shows, which otherwise follows the selection.
  func replyToShowView(_ view: ControlView, project id: String?) -> ControlReply {
    switch view {
    case .agentBoard: showAgentBoard()
    case .allTerminals: setShowsAllTerminals(true)
    case .settings: platform.show(.settings)

    case .projectSettings:
      if let id {
        guard let project = project(withControlID: id) else { return .refused(.noProject(id: id)) }
        requestSettings(for: project)
      }
      platform.show(.projectSettings)
    }
    return .done
  }

  func replyToHideView(_ view: ControlView) -> ControlReply {
    switch view {
    case .agentBoard: hideAgentBoard()
    case .allTerminals: setShowsAllTerminals(false)
    case .settings: platform.close(.settings)
    case .projectSettings: platform.close(.projectSettings)
    }
    return .done
  }
}
