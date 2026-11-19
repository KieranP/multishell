extension KeyCombination {
  /// Interrupt, end of input, suspend, quit and Escape, which a pane's program
  /// needs, and ⌃/, which the pane types as ⌃_ before any menu sees it.
  private static let programKeys: Set<KeyCombination> = Set(
    ["c", "d", "z", "\\", "[", "/"].map { KeyCombination(.character($0), .control) }
  )

  /// Keys a text field moves or deletes by with ⌘, Shift also selecting.
  private static let commandEditingKeys: Set<ShortcutKey> = [
    .leftArrow, .rightArrow, .upArrow, .downArrow, .backspace,
  ]
  /// ⌃⇧← and ⌃⇧→ select to a line's ends, ⌃← and ⌃→ being Spaces'.
  private static let controlEditingKeys: Set<ShortcutKey> = [.leftArrow, .rightArrow]

  /// Keys a text field moves, deletes or breaks a line by with ⌥; it does
  /// nothing with ⌥Home or ⌥End.
  private static let optionEditingKeys: Set<ShortcutKey> = [
    .leftArrow, .rightArrow, .upArrow, .downArrow, .backspace, .forwardDelete, .returnKey, .tab,
    .pageUp, .pageDown,
  ]

  /// Why no command may have these keys, whoever holds them; `nil` where one
  /// may. Docs/design/shortcuts.md has the rules.
  public var refusal: ShortcutRefusal? {
    if modifiers.isDisjoint(with: [.command, .control]), let refusal = refusalWithoutCommand {
      return refusal
    }
    if isTextEditing { return .editsText }
    if let reserved = ReservedShortcut.holding(self) { return .reserved(reserved) }
    // The pane types ⌃↩ with any other modifier before any menu sees it.
    if Self.programKeys.contains(self) || (key == .returnKey && modifiers.contains(.control)) {
      return .programKey(self)
    }
    return nil
  }

  /// Without ⌘ or ⌃ every text field sees the key first, F-keys aside.
  private var refusalWithoutCommand: ShortcutRefusal? {
    if case .function = key { return nil }
    guard modifiers.contains(.option) else { return .needsModifier }
    if typesCharacter { return .optionTypesCharacter }
    return Self.optionEditingKeys.contains(key) ? .optionEditsText : nil
  }

  private var isTextEditing: Bool {
    let byCommand = [[.command], [.command, .shift]].contains(modifiers)
    let byControl = modifiers == [.control, .shift]
    return (byCommand && Self.commandEditingKeys.contains(key))
      || (byControl && Self.controlEditingKeys.contains(key))
  }

  private var typesCharacter: Bool {
    switch key {
    case .character, .space: true
    default: false
    }
  }
}
