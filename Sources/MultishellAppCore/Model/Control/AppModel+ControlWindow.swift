import MultishellCore

extension AppModel {
  func replyToResizeWindow(width: Double, height: Double) -> ControlReply {
    guard !platform.isWorkspaceWindowFullScreen else { return .refused(.windowInFullScreen) }
    return platform.resizeWorkspaceWindow(width: width, height: height)
      ? .done : .refused(.noWindow)
  }

  func replyToSetFullScreen(_ isOn: Bool) -> ControlReply {
    platform.setWorkspaceWindowFullScreen(isOn) ? .done : .refused(.noWindow)
  }
}
