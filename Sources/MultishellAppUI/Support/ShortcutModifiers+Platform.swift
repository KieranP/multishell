import AppKit
import MultishellCore
import SwiftUI

extension ShortcutModifiers {
  /// Each modifier as AppKit's event flags and SwiftUI's shortcut name it.
  private static let platformNames:
    [(modifier: Self, flag: NSEvent.ModifierFlags, eventModifier: EventModifiers)] = [
      (.control, .control, .control), (.option, .option, .option), (.shift, .shift, .shift),
      (.command, .command, .command),
    ]

  var modifierFlags: NSEvent.ModifierFlags {
    NSEvent.ModifierFlags(Self.platformNames.filter { contains($0.modifier) }.map(\.flag))
  }

  var eventModifiers: EventModifiers {
    EventModifiers(Self.platformNames.filter { contains($0.modifier) }.map(\.eventModifier))
  }

  /// The modifiers among an event's flags, Caps Lock, fn and the rest left out.
  init(_ flags: NSEvent.ModifierFlags) {
    self.init(Self.platformNames.filter { flags.contains($0.flag) }.map(\.modifier))
  }
}
