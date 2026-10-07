import MultishellCore

extension AppModel {
  /// The icon picker's glyph, written into the project's own settings over
  /// whatever the repository's file sets. The folder, or `nil`, stores none.
  public func setIconGlyph(_ glyph: String?, for project: Project) {
    var settings = ownSettings(of: project)
    settings.iconGlyph = glyph == ProjectIcon.folderSymbol ? nil : glyph
    setSettings(settings, for: project)
  }

  /// A theme slot to tint the icon from, or `nil` for none.
  public func setIconTint(_ slot: Int?, for project: Project) {
    var settings = ownSettings(of: project)
    settings.iconTint = slot
    setSettings(settings, for: project)
  }
}
