import MultishellCore

extension EditorCatalogue {
  static func displayName(_ id: String) -> String {
    if id == customID { return t("option.custom-command") }
    return editor(id)?.name ?? id
  }
}
