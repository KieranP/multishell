import AppKit
import Carbon
import GhosttyKit

/// macOS's secure keyboard entry, after Ghostty's `SecureInput`: on while a
/// pane wanting it, as at a password prompt, has the keyboard. One switch for the whole Mac.
@MainActor
final class GhosttySecureInput {
  private let isAppActive: () -> Bool
  private let enable: () -> OSStatus
  private let disable: () -> OSStatus
  /// The panes wanting secure input, and whether each has the keyboard.
  private var panes: [ObjectIdentifier: Bool] = [:]
  /// The user's `macos-auto-secure-input`; off, no prompt turns it on.
  var followsPasswordPrompts = true {
    didSet { apply() }
  }
  private var isEnabled = false

  private var isWanted: Bool { followsPasswordPrompts && panes.values.contains(true) }

  init(
    isAppActive: @escaping () -> Bool = { NSApp?.isActive ?? false },
    enable: @escaping () -> OSStatus = EnableSecureEventInput,
    disable: @escaping () -> OSStatus = DisableSecureEventInput,
  ) {
    self.isAppActive = isAppActive
    self.enable = enable
    self.disable = disable
  }

  /// libghostty sets it outright as echo goes off and on; the
  /// `toggle_secure_input` keybind flips it.
  static func wantsSecureInput(after mode: ghostty_action_secure_input_e, was: Bool) -> Bool {
    mode == GHOSTTY_SECURE_INPUT_TOGGLE ? !was : mode == GHOSTTY_SECURE_INPUT_ON
  }

  func update(_ pane: ObjectIdentifier, wantsSecureInput: Bool, hasKeyboard: Bool) {
    panes[pane] = wantsSecureInput ? hasKeyboard : nil
    apply()
  }

  func remove(_ pane: ObjectIdentifier) {
    panes[pane] = nil
    apply()
  }

  func applicationDidBecomeActive() {
    apply()
  }

  /// Held while another app is in front, it would hide that app's keys from
  /// every other one too.
  func applicationDidResignActive() {
    guard isEnabled, disable() == noErr else { return }
    isEnabled = false
  }

  private func apply() {
    guard isAppActive(), isEnabled != isWanted else { return }
    guard (isWanted ? enable() : disable()) == noErr else { return }
    isEnabled = isWanted
  }
}
