import AppKit
import GhosttyKit

/// The modifier keys a chord holds, each down before the key and up after, as
/// a keyboard sends them: libghostty keeps the last modifiers it saw for the mouse.
extension GhosttyKeyInput {
  private static let leftHandKeys = GhosttyModifiers.leftHandKeys

  static func modifierPresses(for flags: NSEvent.ModifierFlags) -> [Self] {
    var held: NSEvent.ModifierFlags = []
    return leftHandKeys.filter { flags.contains($0.flag) }.compactMap { key in
      held.insert(key.flag)
      return modifierChange(key.keyCode, held, GHOSTTY_ACTION_PRESS)
    }
  }

  static func modifierReleases(for flags: NSEvent.ModifierFlags) -> [Self] {
    var held = flags.intersection(NSEvent.ModifierFlags(leftHandKeys.map(\.flag)))
    return leftHandKeys.reversed().filter { flags.contains($0.flag) }.compactMap { key in
      held.remove(key.flag)
      return modifierChange(key.keyCode, held, GHOSTTY_ACTION_RELEASE)
    }
  }

  private static func modifierChange(
    _ keyCode: UInt16,
    _ held: NSEvent.ModifierFlags,
    _ action: ghostty_input_action_e,
  ) -> Self? {
    keyEvent(Int(keyCode), held, .flagsChanged, characters: "", unmodified: "").map { event in
      Self(event, action)
    }
  }
}
