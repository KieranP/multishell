import AppKit

/// A command or control key AppKit offers as a menu equivalent before
/// `keyDown`. terminals.md says why it is typed only on its second offer.
struct GhosttyKeyEquivalent {
  /// When the key now on offer was first passed up, so its second offer, the
  /// same event again, is known; `doCommand` matches on it too.
  private var firstOffer: TimeInterval?

  /// Records the offer, and answers the text to type for a key AppKit would
  /// keep, `nil` to let the menus have it.
  mutating func offer(
    _ charactersIgnoringModifiers: String?,
    characters: String?,
    flags: NSEvent.ModifierFlags,
    timestamp: TimeInterval,
  ) -> String? {
    switch charactersIgnoringModifiers {
    case "\r":
      // Passed through, or AppKit opens the context menu.
      return flags.contains(.control) ? "\r" : nil

    case "/":
      // Control-/ beeps in AppKit; it is Control-_ to a terminal.
      return flags.contains(.control) && flags.isDisjoint(with: [.shift, .command, .option])
        ? "_" : nil

    default:
      // Synthetic, such as the Escape AppKit makes of Command-period.
      guard timestamp != 0 else { return nil }
      guard !flags.isDisjoint(with: [.command, .control]) else {
        firstOffer = nil
        return nil
      }
      if firstOffer == timestamp {
        firstOffer = nil
        return characters ?? ""
      }
      firstOffer = timestamp
      return nil
    }
  }

  func isSecondOffer(at timestamp: TimeInterval) -> Bool {
    firstOffer == timestamp
  }

  /// A key reaching `keyDown` ends whatever was on offer.
  mutating func reset() {
    firstOffer = nil
  }
}
