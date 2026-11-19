import MultishellAppCore
import MultishellCore

extension ShortcutWarning {
  var text: String {
    guard let shellUse else { return t("shortcuts.warning", keys.glyphs) }
    return t("shortcuts.warning-shell", keys.glyphs, shellUse.name)
  }
}
