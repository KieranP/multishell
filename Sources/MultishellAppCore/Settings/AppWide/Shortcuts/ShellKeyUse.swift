import MultishellCore

/// What a shell's line editor does with a ⌃ key, emacs mode as zsh, bash and
/// fish all start in, for the warning on keys a pane gives up.
public enum ShellKeyUse: Character, Sendable {
  case backOneCharacter = "b"
  case clearScreen = "l"
  case deleteLine = "u"
  case deleteToEndOfLine = "k"
  case deleteWord = "w"
  case endOfLine = "e"
  case forwardOneCharacter = "f"
  case historySearch = "r"
  case nextCommand = "n"
  case pasteDeleted = "y"
  case previousCommand = "p"
  case startOfLine = "a"
  case swapCharacters = "t"

  /// `nil` for keys other than ⌃ and a letter the line editor binds.
  init?(_ keys: KeyCombination) {
    guard keys.modifiers == .control, case .character(let character) = keys.key else {
      return nil
    }
    self.init(rawValue: character)
  }
}
