import MultishellCore

extension AppModel {
  func replyToListMenuItems() -> ControlReply {
    .json(platform.menuItems)
  }

  /// As a click on it, so an item greyed out now is refused as the menu would.
  func replyToPerformMenuItem(_ path: [String]) -> ControlReply {
    reply(to: platform.performMenuItem(path), of: path)
  }

  func reply(to outcome: PlatformMenuOutcome, of path: [String]) -> ControlReply {
    let spelled = path.joined(separator: " > ")
    return switch outcome {
    case .performed: .done
    case .disabled: .refused(.menuItemDisabled(path: spelled))
    case .notFound: .refused(.noMenuItem(path: spelled))
    }
  }
}
