import GhosttyKit
import MultishellCore

/// Text the host types into a pane from outside it, `multishell panes type`'s.
extension GhosttySurfaceView {
  /// Typed as an input method commits text, then the Return key, as a person
  /// typing would: a paste's newline is held at a bracketing prompt.
  func typeAsKeys(_ text: String, pressingReturn: Bool) -> Bool {
    guard surface != nil else { return false }
    if !text.isEmpty { send(GhosttyKeyInput(committing: text)) }
    if pressingReturn {
      send(.returnKey(GHOSTTY_ACTION_PRESS))
      send(.returnKey(GHOSTTY_ACTION_RELEASE))
    }
    return true
  }

  /// Each key down then up, in turn, as a person pressing them would; `false`
  /// for a key with no code here, so the command line is not told it was pressed.
  func press(_ keys: [ControlKey]) -> Bool {
    guard let surface else { return false }
    for key in keys {
      let flags = translationFlags(for: key.modifierFlags, on: surface)
      guard let down = GhosttyKeyInput(key, GHOSTTY_ACTION_PRESS, translationFlags: flags),
        let up = GhosttyKeyInput(key, GHOSTTY_ACTION_RELEASE)
      else { return false }
      GhosttyKeyInput.modifierPresses(for: key.modifierFlags).forEach(send)
      send(down)
      send(up)
      GhosttyKeyInput.modifierReleases(for: key.modifierFlags).forEach(send)
    }
    return true
  }
}
