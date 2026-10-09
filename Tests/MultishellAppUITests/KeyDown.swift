import AppKit
import Testing

/// A key-down event built in a test. What a key types depends on the keyboard
/// layout in use, so a test reads that back from the event rather than assume US.
@MainActor
func keyDown(
  _ characters: String,
  keyCode: UInt16,
  flags: NSEvent.ModifierFlags = [],
) throws -> NSEvent {
  try #require(
    NSEvent.keyEvent(
      with: .keyDown,
      location: .zero,
      modifierFlags: flags,
      timestamp: 1,
      windowNumber: 0,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: characters,
      isARepeat: false,
      keyCode: keyCode,
    )
  )
}
