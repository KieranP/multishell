import MultishellCore

extension AppModel {
  /// The icon picker's glyph, written into the project's own settings over
  /// whatever the repository's file sets; `nil` is the folder.
  public func setIconGlyph(_ glyph: String?, for project: Project) {
    var settings = ownSettings(of: project)
    settings.iconGlyph = glyph
    updateSettings(settings, for: project)
  }

  /// A theme slot to tint the icon from, or `nil` for none.
  public func setIconTint(_ slot: Int?, for project: Project) {
    var settings = ownSettings(of: project)
    settings.iconTint = slot
    updateSettings(settings, for: project)
  }
}
