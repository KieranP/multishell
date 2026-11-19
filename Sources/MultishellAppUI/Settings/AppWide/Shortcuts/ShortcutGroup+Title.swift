import MultishellAppCore

extension ShortcutGroup {
  var title: String {
    switch self {
    case .newItems: t("shortcuts.group-new")
    case .closeItems: t("shortcuts.group-close")
    case .editing: t("shortcuts.group-edit")
    case .find: t("shortcuts.group-find")
    case .show: t("shortcuts.group-show")
    case .filesPanel: t("shortcuts.group-files-panel")
    case .panes: t("shortcuts.group-panes")
    case .groups: t("shortcuts.group-groups")
    case .tabs: t("shortcuts.group-tabs")
    }
  }

  /// Help behind the card title's (i), where its rows need some.
  var info: String? {
    self == .editing ? t("shortcuts.group-edit-info") : nil
  }
}
