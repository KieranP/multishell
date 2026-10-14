import AppKit
import GhosttyKit

/// Keys reach libghostty through AppKit's input system, after Ghostty's own
/// `SurfaceView_AppKit.keyDown`, so input methods compose as in any text view.
extension GhosttySurfaceView {
  override func keyDown(with event: NSEvent) {
    guard let surface else {
      interpretKeyEvents([event])
      return
    }
    let action = event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS
    let translated = event.translated(to: translationFlags(for: event.modifierFlags, on: surface))
    let wasComposing = !markedText.isEmpty
    let layoutBefore = wasComposing ? nil : KeyboardInputSource.currentID
    textCommittedInKeyDown = []
    defer { textCommittedInKeyDown = nil }
    keyEquivalent.reset()

    interpretKeyEvents([translated])
    // A key that switched the input source was the system's to act on.
    if !wasComposing, layoutBefore != KeyboardInputSource.currentID { return }
    syncPreedit(clearingIfEmpty: wasComposing)

    let deliveries = GhosttyKeyDown.deliveries(
      wasComposing: wasComposing,
      isComposing: !markedText.isEmpty,
      committed: textCommittedInKeyDown ?? [],
      characters: event.characters,
      keyText: translated.ghosttyText,
      keyCode: translated.keyCode,
      flags: translated.modifierFlags,
    )
    for delivery in deliveries {
      switch delivery {
      case .committed(let text):
        send(GhosttyKeyInput(committing: text, action))

      case .key(let text, let isComposing):
        var input = GhosttyKeyInput(
          event,
          action,
          translationFlags: translated.modifierFlags,
          text: text,
        )
        input.isComposing = isComposing
        send(input)
      }
    }
  }

  override func keyUp(with event: NSEvent) {
    send(GhosttyKeyInput(event, GHOSTTY_ACTION_RELEASE))
  }

  /// A command key's release, which AppKit hands to no view, sent here so a
  /// program tracking releases sees one.
  func takeCommandKeyUp(_ event: NSEvent) -> Bool {
    guard event.modifierFlags.contains(.command), event.window === window, hasKeyboard else {
      return false
    }
    keyUp(with: event)
    return true
  }

  /// A press only when the side that changed is the one now down, not its
  /// twin still held. Left alone mid-composition, which the IME owns.
  override func flagsChanged(with event: NSEvent) {
    guard let mod = GhosttyModifiers.mod(forKeyCode: event.keyCode), markedText.isEmpty else {
      return
    }
    let flags = event.modifierFlags
    let isDown =
      GhosttyModifiers.mods(flags).rawValue & mod.rawValue != 0
      && GhosttyModifiers.isOwnSideDown(keyCode: event.keyCode, in: flags)
    send(GhosttyKeyInput(event, isDown ? GHOSTTY_ACTION_PRESS : GHOSTTY_ACTION_RELEASE))
  }

  func send(_ input: GhosttyKeyInput) {
    guard let surface else { return }
    input.withCValue { _ = ghostty_surface_key(surface, $0) }
  }

  /// `flags` with the modifiers libghostty translates with (Option as Alt), the rest kept.
  func translationFlags(
    for flags: NSEvent.ModifierFlags,
    on surface: ghostty_surface_t,
  ) -> NSEvent.ModifierFlags {
    let wanted = GhosttyModifiers.flags(
      ghostty_surface_key_translation_mods(surface, GhosttyModifiers.mods(flags))
    )
    var translation = flags
    for flag in [NSEvent.ModifierFlags.shift, .control, .option, .command] {
      if wanted.contains(flag) { translation.insert(flag) } else { translation.remove(flag) }
    }
    return translation
  }
}
