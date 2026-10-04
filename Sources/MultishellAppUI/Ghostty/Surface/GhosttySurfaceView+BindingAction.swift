import GhosttyKit

extension GhosttySurfaceView {
  /// A keybind action by Ghostty's name for it, `false` where it did nothing.
  @discardableResult
  func performBindingAction(_ action: String) -> Bool {
    guard let surface else { return false }
    return action.withCStringAndLength { ghostty_surface_binding_action(surface, $0, $1) }
  }
}
