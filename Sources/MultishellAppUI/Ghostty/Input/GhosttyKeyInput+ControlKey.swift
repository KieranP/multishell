import AppKit
import Carbon.HIToolbox
import GhosttyKit
import MultishellCore

/// A key the command line names, by a US keyboard's codes.
extension GhosttyKeyInput {
  private static let namedKeyCodes: [String: Int] = [
    "enter": kVK_Return, "escape": kVK_Escape, "tab": kVK_Tab, "backspace": kVK_Delete,
    "delete": kVK_ForwardDelete, "space": kVK_Space, "up": kVK_UpArrow, "down": kVK_DownArrow,
    "left": kVK_LeftArrow, "right": kVK_RightArrow, "home": kVK_Home, "end": kVK_End,
    "pageup": kVK_PageUp, "pagedown": kVK_PageDown, "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3,
    "f4": kVK_F4, "f5": kVK_F5, "f6": kVK_F6, "f7": kVK_F7, "f8": kVK_F8, "f9": kVK_F9,
    "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
  ]

  private static let characterKeyCodes: [Character: Int] = [
    "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E,
    "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J,
    "k": kVK_ANSI_K, "l": kVK_ANSI_L, "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O,
    "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
    "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X, "y": kVK_ANSI_Y,
    "z": kVK_ANSI_Z, "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
    "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8,
    "9": kVK_ANSI_9, "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal, "[": kVK_ANSI_LeftBracket,
    "]": kVK_ANSI_RightBracket, ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote,
    ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period, "/": kVK_ANSI_Slash, "`": kVK_ANSI_Grave,
    "\\": kVK_ANSI_Backslash,
  ]

  /// As a real press reaches libghostty: text from the layout, under the
  /// modifiers libghostty translates with (Option as Alt).
  init?(
    _ key: ControlKey,
    _ action: ghostty_input_action_e,
    translationFlags: NSEvent.ModifierFlags? = nil,
  ) {
    let type: NSEvent.EventType = action == GHOSTTY_ACTION_RELEASE ? .keyUp : .keyDown
    guard let event = Self.event(for: key, type) else { return nil }
    let flags = translationFlags ?? event.modifierFlags
    let translated = event.translated(to: flags)
    self.init(
      event,
      action,
      translationFlags: flags,
      text: type == .keyUp ? nil : translated.ghosttyText,
    )
  }

  /// A key event for `key` with the characters the current layout gives it,
  /// which AppKit works out from the code as it does for a real press.
  private static func event(for key: ControlKey, _ type: NSEvent.EventType) -> NSEvent? {
    let character = key.key.count == 1 ? key.key.first : nil
    guard
      let code = character.flatMap({ characterKeyCodes[$0] }) ?? namedKeyCodes[key.key]
    else { return nil }
    let flags = key.modifierFlags
    let probe = keyEvent(code, flags, type, characters: "", unmodified: "")
    return keyEvent(
      code,
      flags,
      type,
      characters: probe?.characters(byApplyingModifiers: flags) ?? "",
      unmodified: probe?.characters(byApplyingModifiers: []) ?? "",
    )
  }

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
