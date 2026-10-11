import MultishellCore

extension AppModel {
  func answerListMenuItems() -> ControlReply {
    .json(platform.menuItems)
  }

  /// As a click on it, so an item greyed out now is refused as the menu would.
  func answerPerformMenuItem(_ path: [String]) -> ControlReply {
    let spelled = path.joined(separator: " > ")
    return switch platform.performMenuItem(path) {
    case .performed: .done
    case .disabled: .refused(.menuItemDisabled(path: spelled))
    case .notFound: .refused(.noMenuItem(path: spelled))
    }
  }
}
