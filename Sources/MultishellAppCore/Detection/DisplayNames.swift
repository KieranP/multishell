import MultishellCore

/// What the dropdowns and captions call a stored id.
extension AgentCatalogue {
  public static func displayName(_ id: String) -> String {
    if id == customID { return "Custom command" }
    return agent(id)?.name ?? id
  }
}

extension EditorCatalogue {
  public static func displayName(_ id: String) -> String {
    if id == customID { return "Custom command" }
    return editor(id)?.name ?? id
  }
}

extension ShellCatalogue {
  /// A path is its own name; the login shell and the custom path say what
  /// they currently resolve to.
  public static func displayName(_ id: String?, customPath: String, loginShell: String) -> String {
    guard let id, id != loginShellID else { return "the login shell (\(loginShell))" }
    guard id == customID else { return id }
    let path = customPath.trimmingCharacters(in: .whitespaces)
    return path.isEmpty ? "the custom path, blank, so the login shell" : "the custom path \(path)"
  }
}
