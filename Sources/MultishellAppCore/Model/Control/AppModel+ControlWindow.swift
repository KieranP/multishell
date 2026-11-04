import MultishellCore

extension AppModel {
  /// Open, covered or minimized; `isWorkspaceWindowVisible` is whether any of it
  /// is on a screen, which a request drawn in the window does not need.
  var isWorkspaceWindowOpen: Bool { platform.workspaceWindowWidth != nil }

  /// Shut or off screen, where neither a file tab nor the Files panel reads.
  var refusalToReadInWorkspaceWindow: ControlRefusal? {
    if let refusal = refusalToTouchWorkspaceWindow { return refusal }
    return platform.isWorkspaceWindowVisible ? nil : .windowCovered
  }

  /// Shut or in the Dock, where AppKit neither sizes the window nor draws it.
  private var refusalToTouchWorkspaceWindow: ControlRefusal? {
    guard isWorkspaceWindowOpen else { return .noWindow }
    return platform.isWorkspaceWindowMinimized ? .windowMinimized : nil
  }

  func replyToResizeWindow(width: Double, height: Double) -> ControlReply {
    guard !platform.isWorkspaceWindowFullScreen else { return .refused(.windowInFullScreen) }
    if let refusal = refusalToTouchWorkspaceWindow { return .refused(refusal) }
    return platform.resizeWorkspaceWindow(width: width, height: height)
      ? .done : .refused(.noWindow)
  }

  func replyToSetFullScreen(_ isOn: Bool) -> ControlReply {
    if let refusal = refusalToTouchWorkspaceWindow { return .refused(refusal) }
    return platform.setWorkspaceWindowFullScreen(isOn) ? .done : .refused(.noWindow)
  }
}
