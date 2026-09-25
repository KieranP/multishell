import MultishellCore

/// What the dropdowns and captions call a stored id.
extension AgentCatalogue {
  public static func displayName(_ id: String) -> String {
    if id == customID { return t("option.custom-command") }
    return agent(id)?.name ?? id
  }
}
