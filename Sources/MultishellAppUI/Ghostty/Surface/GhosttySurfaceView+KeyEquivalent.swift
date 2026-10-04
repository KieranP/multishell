import AppKit
import GhosttyKit

/// Command and control keys AppKit offers as menu equivalents before
/// `keyDown`, after Ghostty's own `performKeyEquivalent`.
extension GhosttySurfaceView {
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    // AppKit offers some, Control-/ among them, to the first view in the
    // window rather than the first responder.
    guard event.type == .keyDown, window?.firstResponder === self else { return false }
    if isBinding(event) {
      keyDown(with: event)
      return true
    }
    guard
      let equivalent = keyEquivalent.offer(
        event.charactersIgnoringModifiers, characters: event.characters,
        flags: event.modifierFlags, timestamp: event.timestamp)
    else { return false }
    guard
      let replacement = event.keyCopy(
        characters: equivalent, charactersIgnoringModifiers: equivalent)
    else { return false }
    keyDown(with: replacement)
    return true
  }

  /// A command or control key AppKit turns into an editing command rather
  /// than delivering, sent back through as the key; see `GhosttyKeyEquivalent`.
  override func doCommand(by selector: Selector) {
    guard let current = NSApp.currentEvent, keyEquivalent.isSecondOffer(at: current.timestamp)
    else {
      return
    }
    NSApp.sendEvent(current)
  }

  /// libghostty binds the key, so it acts before any menu does; the menus'
  /// own keys are unbound for that reason (`GhosttyUnbinds`).
  private func isBinding(_ event: NSEvent) -> Bool {
    guard let surface else { return false }
    var flags = ghostty_binding_flags_e(0)
    let input = GhosttyKeyInput(event, GHOSTTY_ACTION_PRESS, text: event.characters)
    return input.withCValue { ghostty_surface_key_is_binding(surface, $0, &flags) }
  }
}
