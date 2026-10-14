import AppKit

/// A key event made here rather than typed, for a key the command line names
/// or a modifier a chord holds.
extension GhosttyKeyInput {
  static func keyEvent(
    _ code: Int,
    _ flags: NSEvent.ModifierFlags,
    _ type: NSEvent.EventType,
    characters: String,
    unmodified: String,
  ) -> NSEvent? {
    NSEvent.keyEvent(
      with: type,
      location: .zero,
      modifierFlags: flags,
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: 0,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: unmodified,
      isARepeat: false,
      keyCode: UInt16(code),
    )
  }
}
