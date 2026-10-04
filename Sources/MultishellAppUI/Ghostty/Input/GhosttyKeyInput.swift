import AppKit
import GhosttyKit

/// One key event as libghostty takes it, after Ghostty's own
/// `NSEvent.ghosttyKeyEvent`. The text stays a Swift string until it is sent.
struct GhosttyKeyInput {
  let action: ghostty_input_action_e
  let keyCode: UInt32
  let mods: ghostty_input_mods_e
  let consumedMods: ghostty_input_mods_e
  let unshiftedCodepoint: UInt32
  let text: String?
  var isComposing = false

  /// `translationFlags` are the modifiers that made the text, where libghostty
  /// changed them (option as alt). Control and command never make text.
  init(
    _ event: NSEvent, _ action: ghostty_input_action_e,
    translationFlags: NSEvent.ModifierFlags? = nil, text: String? = nil
  ) {
    self.action = action
    keyCode = UInt32(event.keyCode)
    mods = GhosttyModifiers.mods(event.modifierFlags)
    consumedMods = GhosttyModifiers.mods(
      (translationFlags ?? event.modifierFlags).subtracting([.control, .command]))
    let isKey = event.type == .keyDown || event.type == .keyUp
    unshiftedCodepoint =
      isKey ? event.characters(byApplyingModifiers: [])?.unicodeScalars.first?.value ?? 0 : 0
    self.text = Self.textUnlessControl(text)
  }

  /// Text an input method commits rather than a key types. Keycode 0 and no
  /// modifiers, so libghostty encodes the text alone.
  init(committing text: String, _ action: ghostty_input_action_e = GHOSTTY_ACTION_PRESS) {
    self.action = action
    keyCode = 0
    mods = GHOSTTY_MODS_NONE
    consumedMods = GHOSTTY_MODS_NONE
    unshiftedCodepoint = 0
    self.text = text
  }

  func withCValue<Result>(_ body: (ghostty_input_key_s) -> Result) -> Result {
    var key = ghostty_input_key_s(
      action: action, mods: mods, consumed_mods: consumedMods, keycode: keyCode, text: nil,
      unshifted_codepoint: unshiftedCodepoint, composing: isComposing)
    guard let text else { return body(key) }
    return text.withCString { pointer in
      key.text = pointer
      return body(key)
    }
  }

  /// libghostty encodes control characters itself from the key and its
  /// modifiers, which the Kitty keyboard protocol needs, so they go as no text.
  private static func textUnlessControl(_ text: String?) -> String? {
    guard let text, let first = text.unicodeScalars.first else { return nil }
    return first.value < 0x20 || first.value == 0x7F ? nil : text
  }
}
