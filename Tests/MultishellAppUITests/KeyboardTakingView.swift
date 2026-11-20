import AppKit

/// Stands in for a terminal surface, an AppKit view that takes the keyboard.
final class KeyboardTakingView: NSView {
  override var acceptsFirstResponder: Bool { true }
}
