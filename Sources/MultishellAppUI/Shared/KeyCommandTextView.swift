import AppKit

/// A text view that hands ⌘↩ and Escape to its owner where it has a closure for
/// them, as a form's field would; without one they do what a text view does.
final class KeyCommandTextView: NSTextView {
  private static let returnKey: UInt16 = 36
  private static let enterKey: UInt16 = 76
  private static let escapeKey: UInt16 = 53
  /// Caps Lock and the keypad's or fn's flags say nothing about the command meant.
  private static let ignoredModifiers: NSEvent.ModifierFlags = [.capsLock, .numericPad, .function]

  var commit: (() -> Void)?
  var cancel: (() -> Void)?

  /// An input method still composing gets the key, Escape dropping its candidates.
  override func keyDown(with event: NSEvent) {
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      .subtracting(Self.ignoredModifiers)
    let isReturn = event.keyCode == Self.returnKey || event.keyCode == Self.enterKey
    if !hasMarkedText(), isReturn, modifiers == .command, let commit {
      commit()
    } else if !hasMarkedText(), event.keyCode == Self.escapeKey, modifiers.isEmpty, let cancel {
      cancel()
    } else {
      super.keyDown(with: event)
    }
  }
}
