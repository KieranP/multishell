import AppKit

extension GhosttySurfaceView {
  /// Secure input follows the keyboard: on only while this prompt has it.
  /// `hasKeyboard` is passed in, AppKit naming a new responder only afterwards.
  func syncSecureInput(hasKeyboard: Bool) {
    runtime.secureInput.update(
      ObjectIdentifier(self), wantsSecureInput: wantsSecureInput, hasKeyboard: hasKeyboard)
  }
}
