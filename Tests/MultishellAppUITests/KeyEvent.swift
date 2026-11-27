import AppKit
import Testing

/// A key event built in a test. What a key types depends on the keyboard
/// layout in use, so a test reads that back from the event rather than assume US.
@MainActor
func keyEvent(
  _ type: NSEvent.EventType,
  _ characters: String,
  keyCode: UInt16,
  flags: NSEvent.ModifierFlags = [],
  windowNumber: Int = 0,
) throws -> NSEvent {
  try #require(
    NSEvent.keyEvent(
      with: type,
      location: .zero,
      modifierFlags: flags,
      timestamp: 1,
      windowNumber: windowNumber,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: characters,
      isARepeat: false,
      keyCode: keyCode,
    )
  )
}

@MainActor
func keyDown(
  _ characters: String,
  keyCode: UInt16,
  flags: NSEvent.ModifierFlags = [],
) throws -> NSEvent {
  try keyEvent(.keyDown, characters, keyCode: keyCode, flags: flags)
}
