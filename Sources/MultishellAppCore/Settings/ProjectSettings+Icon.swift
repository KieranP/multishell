import MultishellCore

extension ProjectSettings {
  /// What the project's glyph draws as, for the sidebar, the header, the
  /// new-worktree picker and the icon's own settings row alike.
  public var iconKind: ProjectIcon.Kind { ProjectIcon.kind(of: iconGlyph) }
}
