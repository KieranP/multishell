import AppKit

/// What one key-down sends libghostty, decided from what the input method did
/// with it, after Ghostty's own `SurfaceView_AppKit.keyDown`.
enum GhosttyKeyDown {
  enum Delivery: Equatable {
    /// Text an input method committed, sent as text alone.
    case committed(String)
    /// The key itself, with the text it typed where it typed any.
    case key(text: String?, isComposing: Bool)
  }

  /// `keyText` is what the key types with no input method in the way; the
  /// key's own `characters` say whether that is a control the IME owns.
  static func deliveries(
    wasComposing: Bool, isComposing: Bool, committed: [String], characters: String?,
    keyText: String?, keyCode: UInt16, flags: NSEvent.ModifierFlags
  ) -> [Delivery] {
    let isOrWasComposing = isComposing || wasComposing
    let typed = committed.filter { !isComposingControl($0, whileComposing: isOrWasComposing) }
    if wasComposing, !committed.isEmpty {
      let replays = replaysAfterCommit(keyCode: keyCode, flags: flags)
      return typed.map(Delivery.committed) + (replays ? [.key(text: nil, isComposing: false)] : [])
    }
    if !committed.isEmpty {
      return typed.map { .key(text: $0, isComposing: false) }
    }
    if isComposingControl(characters, whileComposing: isOrWasComposing) { return [] }
    return [.key(text: keyText, isComposing: isOrWasComposing)]
  }

  /// A lone control character while composing is the input method's.
  private static func isComposingControl(_ text: String?, whileComposing: Bool) -> Bool {
    guard whileComposing, let scalars = text?.unicodeScalars, scalars.count == 1 else {
      return false
    }
    return scalars.first!.value < 0x20
  }

  /// Arrows still move after the input method commits on them; plain Left
  /// does not, the Korean input methods leaving the caret in place.
  private static func replaysAfterCommit(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
    let (left, right, down, up): (UInt16, UInt16, UInt16, UInt16) = (0x7B, 0x7C, 0x7D, 0x7E)
    switch keyCode {
    case right, down, up: return true
    case left: return !flags.isDisjoint(with: [.shift, .control, .option, .command])
    default: return false
    }
  }
}
