import AppKit
import MultishellCore

extension ControlKey {
  var modifierFlags: NSEvent.ModifierFlags {
    NSEvent.ModifierFlags(
      modifiers.map { modifier in
        switch modifier {
        case .command: .command
        case .control: .control
        case .option: .option
        case .shift: .shift
        }
      }
    )
  }
}
