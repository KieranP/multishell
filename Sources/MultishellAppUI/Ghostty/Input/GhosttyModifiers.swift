import AppKit
import Carbon.HIToolbox
import GhosttyKit

/// AppKit's modifier flags in libghostty's spelling and back, after Ghostty's
/// own `Ghostty.Input` conversions.
enum GhosttyModifiers {
  private typealias ModifierKey = (
    keyCode: UInt16, mod: ghostty_input_mods_e, deviceMask: Int32,
    rightHandMod: ghostty_input_mods_e?
  )

  /// Keycodes are AppKit's; the device masks are the side bits AppKit leaves
  /// in a flag's raw value.
  private static let modifierKeys: [ModifierKey] = [
    (UInt16(kVK_Shift), GHOSTTY_MODS_SHIFT, NX_DEVICELSHIFTKEYMASK, nil),
    (UInt16(kVK_RightShift), GHOSTTY_MODS_SHIFT, NX_DEVICERSHIFTKEYMASK, GHOSTTY_MODS_SHIFT_RIGHT),
    (UInt16(kVK_Control), GHOSTTY_MODS_CTRL, NX_DEVICELCTLKEYMASK, nil),
    (UInt16(kVK_RightControl), GHOSTTY_MODS_CTRL, NX_DEVICERCTLKEYMASK, GHOSTTY_MODS_CTRL_RIGHT),
    (UInt16(kVK_Option), GHOSTTY_MODS_ALT, NX_DEVICELALTKEYMASK, nil),
    (UInt16(kVK_RightOption), GHOSTTY_MODS_ALT, NX_DEVICERALTKEYMASK, GHOSTTY_MODS_ALT_RIGHT),
    (UInt16(kVK_Command), GHOSTTY_MODS_SUPER, NX_DEVICELCMDKEYMASK, nil),
    (UInt16(kVK_RightCommand), GHOSTTY_MODS_SUPER, NX_DEVICERCMDKEYMASK, GHOSTTY_MODS_SUPER_RIGHT),
  ]

  /// The left-hand key of each modifier, in the order a chord presses them.
  static let leftHandKeys: [(flag: NSEvent.ModifierFlags, keyCode: UInt16)] =
    modifierKeys.filter { $0.rightHandMod == nil }.map { (flags($0.mod), $0.keyCode) }

  private static let rightHandMods = modifierKeys.compactMap { key in
    key.rightHandMod.map { (deviceMask: key.deviceMask, mod: $0) }
  }

  private static let capsLockKeyCode = UInt16(kVK_CapsLock)

  private static let sidelessMods: [(NSEvent.ModifierFlags, ghostty_input_mods_e)] = [
    (.shift, GHOSTTY_MODS_SHIFT), (.control, GHOSTTY_MODS_CTRL), (.option, GHOSTTY_MODS_ALT),
    (.command, GHOSTTY_MODS_SUPER),
  ]

  /// The right-hand bits are what let `macos-option-as-alt = left` tell the
  /// two Option keys apart.
  static func mods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
    var mods = GHOSTTY_MODS_NONE.rawValue
    for (flag, mod) in sidelessMods where flags.contains(flag) { mods |= mod.rawValue }
    if flags.contains(.capsLock) { mods |= GHOSTTY_MODS_CAPS.rawValue }
    for (deviceMask, rightHandMod) in rightHandMods where holds(flags, deviceMask) {
      mods |= rightHandMod.rawValue
    }
    return ghostty_input_mods_e(mods)
  }

  static func flags(_ mods: ghostty_input_mods_e) -> NSEvent.ModifierFlags {
    sidelessMods.reduce(into: []) { flags, pair in
      if mods.rawValue & pair.1.rawValue != 0 { flags.insert(pair.0) }
    }
  }

  /// Whether the key `flagsChanged` reports is down rather than its twin. A made-up
  /// event may carry neither side's bit, and a key that is no modifier has none: both are down.
  static func isOwnSideDown(keyCode: UInt16, in flags: NSEvent.ModifierFlags) -> Bool {
    guard let key = modifierKeys.first(where: { $0.keyCode == keyCode }) else { return true }
    if holds(flags, key.deviceMask) { return true }
    let twins = modifierKeys.filter { $0.mod == key.mod && $0.keyCode != keyCode }
    return !twins.contains { holds(flags, $0.deviceMask) }
  }

  /// The libghostty modifier a modifier key's own keycode stands for.
  static func mod(forKeyCode keyCode: UInt16) -> ghostty_input_mods_e? {
    if keyCode == capsLockKeyCode { return GHOSTTY_MODS_CAPS }
    return modifierKeys.first { $0.keyCode == keyCode }?.mod
  }

  private static func holds(_ flags: NSEvent.ModifierFlags, _ deviceMask: Int32) -> Bool {
    flags.rawValue & UInt(deviceMask) != 0
  }
}
