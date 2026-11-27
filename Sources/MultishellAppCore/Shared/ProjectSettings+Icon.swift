import MultishellCore

extension ProjectSettings {
  /// What the project's glyph draws as, the same wherever a project is drawn.
  public var iconKind: ProjectIcon.Kind { ProjectIcon.kind(of: iconGlyph) }
}
