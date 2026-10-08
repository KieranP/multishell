import MultishellCore

extension SessionState? {
  /// The state a dot, a glyph or a screen reader shows: none is Idle.
  public var shownState: SessionState { self ?? .idle }
}
