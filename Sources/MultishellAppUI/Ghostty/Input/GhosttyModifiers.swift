import AppKit
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
    (0x38, GHOSTTY_MODS_SHIFT, NX_DEVICELSHIFTKEYMASK, nil),
    (0x3C, GHOSTTY_MODS_SHIFT, NX_DEVICERSHIFTKEYMASK, GHOSTTY_MODS_SHIFT_RIGHT),
    (0x3B, GHOSTTY_MODS_CTRL, NX_DEVICELCTLKEYMASK, nil),
    (0x3E, GHOSTTY_MODS_CTRL, NX_DEVICERCTLKEYMASK, GHOSTTY_MODS_CTRL_RIGHT),
    (0x3A, GHOSTTY_MODS_ALT, NX_DEVICELALTKEYMASK, nil),
    (0x3D, GHOSTTY_MODS_ALT, NX_DEVICERALTKEYMASK, GHOSTTY_MODS_ALT_RIGHT),
    (0x37, GHOSTTY_MODS_SUPER, NX_DEVICELCMDKEYMASK, nil),
    (0x36, GHOSTTY_MODS_SUPER, NX_DEVICERCMDKEYMASK, GHOSTTY_MODS_SUPER_RIGHT),
  ]

  private static let rightHandMods = modifierKeys.compactMap { key in
    key.rightHandMod.map { (deviceMask: key.deviceMask, mod: $0) }
  }

  private static let capsLockKeyCode: UInt16 = 0x39

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
