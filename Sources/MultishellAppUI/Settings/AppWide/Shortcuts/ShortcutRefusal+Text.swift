import MultishellAppCore
import MultishellCore

extension ShortcutRefusal {
  var text: String {
    switch self {
    case .editsText: t("shortcuts.refused-edits-text")
    case .needsModifier: t("shortcuts.refused-needs-modifier")
    case .optionEditsText: t("shortcuts.refused-option-edits-text")
    case .optionTypesCharacter: t("shortcuts.refused-option-character")

    case .reserved(let reserved):
      t("shortcuts.refused-reserved", reserved.combination.glyphs, reserved.use)

    case .programKey(let keys): t("shortcuts.refused-program-key", keys.glyphs)

    case .heldByFixed(let command):
      t("shortcuts.refused-fixed", command.defaultCombination.glyphs, command.menuTitle)
    }
  }
}
