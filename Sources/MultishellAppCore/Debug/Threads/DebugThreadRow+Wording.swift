import MultishellCore

extension DebugThreadRow {
  /// Ghostty's names as Ghostty gave them; the main thread and the unnamed by group.
  public var title: String {
    if key.group == .main { return t("debug.thread.main") }
    return key.name.isEmpty ? t("debug.thread.unnamed") : key.name
  }
}
