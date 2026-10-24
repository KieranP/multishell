import MultishellCore

extension AppModel {
  /// The view a session draws into, from whichever engine opened it: the one
  /// thing a view takes from the host.
  public func surface(for id: TerminalSession.ID) -> Surface? {
    host.view(for: id)
  }

  /// The user clicked into a surface's frame: the engine makes it first
  /// responder and reports the focus back through the reconciler.
  public func focusSurface(_ id: TerminalSession.ID) {
    host.focus(id)
  }
}
