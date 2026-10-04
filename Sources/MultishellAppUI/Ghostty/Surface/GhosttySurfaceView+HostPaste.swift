import GhosttyKit

/// Text the host drops or pastes into a pane from outside it.
extension GhosttySurfaceView {
  /// Typed as a paste, so libghostty brackets it for a program that asked.
  @discardableResult
  func typeAsPaste(_ text: String) -> Bool {
    guard let surface else { return false }
    text.withCStringAndLength { ghostty_surface_text(surface, $0, $1) }
    return true
  }
}
