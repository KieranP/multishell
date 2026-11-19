import AppKit
import MultishellCore

extension KeyCombination {
  /// The character a menu item's key equivalent holds for the key: the
  /// character itself, or the code or private-use character AppKit names it by.
  var menuKeyCharacter: Character {
    switch key {
    case .character(let character): character
    case .function(let number): Self.scalar(NSF1FunctionKey + number - 1)
    case .tab: "\t"
    case .returnKey: "\r"
    case .space: " "
    case .backspace: "\u{8}"
    case .forwardDelete: Self.scalar(NSDeleteFunctionKey)
    case .home: Self.scalar(NSHomeFunctionKey)
    case .end: Self.scalar(NSEndFunctionKey)
    case .pageUp: Self.scalar(NSPageUpFunctionKey)
    case .pageDown: Self.scalar(NSPageDownFunctionKey)
    case .leftArrow: Self.scalar(NSLeftArrowFunctionKey)
    case .rightArrow: Self.scalar(NSRightArrowFunctionKey)
    case .upArrow: Self.scalar(NSUpArrowFunctionKey)
    case .downArrow: Self.scalar(NSDownArrowFunctionKey)
    }
  }

  private static func scalar(_ value: Int) -> Character {
    UnicodeScalar(UInt32(value)).map(Character.init) ?? " "
  }
}
