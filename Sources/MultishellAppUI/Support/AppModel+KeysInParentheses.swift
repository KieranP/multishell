import MultishellAppCore
import MultishellCore

extension AppModel {
  /// ` (⌘T)` for a sentence naming the command's keys in force, and nothing
  /// where it has none, so no empty parenthesis is left.
  func keysInParentheses(_ command: ShortcutCommand) -> String {
    shortcutKeys(for: command).map { t("shortcuts.in-parentheses", $0.glyphs) } ?? ""
  }
}
