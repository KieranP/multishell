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
    let translation = translated(event, on: surface)
    let wasComposing = !markedText.isEmpty
    let layoutBefore = wasComposing ? nil : KeyboardInputSource.currentID
    textCommittedInKeyDown = []
    defer { textCommittedInKeyDown = nil }
    keyEquivalent.reset()

    interpretKeyEvents([translation])
    // A key that switched the input source was the system's to act on.
    if !wasComposing, layoutBefore != KeyboardInputSource.currentID { return }
    syncPreedit(clearingIfEmpty: wasComposing)

    let deliveries = GhosttyKeyDown.deliveries(
      wasComposing: wasComposing, isComposing: !markedText.isEmpty,
      committed: textCommittedInKeyDown ?? [], characters: event.characters,
      keyText: translation.ghosttyText, keyCode: translation.keyCode,
      flags: translation.modifierFlags)
    for delivery in deliveries {
      switch delivery {
      case .committed(let text):
        send(GhosttyKeyInput(committing: text, action))
      case .key(let text, let isComposing):
        var input = GhosttyKeyInput(
          event, action, translationFlags: translation.modifierFlags, text: text)
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

  /// The event with the modifiers libghostty translates with (Option as Alt);
  /// the original where unchanged, as Korean input breaks on a copy.
  private func translated(_ event: NSEvent, on surface: ghostty_surface_t) -> NSEvent {
    let wanted = GhosttyModifiers.flags(
      ghostty_surface_key_translation_mods(surface, GhosttyModifiers.mods(event.modifierFlags)))
    var flags = event.modifierFlags
    for flag in [NSEvent.ModifierFlags.shift, .control, .option, .command] {
      if wanted.contains(flag) { flags.insert(flag) } else { flags.remove(flag) }
    }
    guard flags != event.modifierFlags else { return event }
    return event.keyCopy(
      modifierFlags: flags, characters: event.characters(byApplyingModifiers: flags) ?? "",
      charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? "") ?? event
  }
}
