import MultishellCore

extension AppModel {
  /// The icon picker's glyph, written into the project's own settings over
  /// whatever the repository's file sets.
  public func setIconGlyph(_ glyph: String?, for project: Project) {
    var settings = ownSettings(of: project)
    settings.iconGlyph = ProjectIcon.storedGlyph(
      picking: glyph,
      over: project.sharedSettingsSnapshot.confined?.iconGlyph,
    )
    setSettings(settings, for: project)
  }

  /// A theme slot to tint the icon from, or `nil` for none.
  public func setIconTint(_ slot: Int?, for project: Project) {
    var settings = ownSettings(of: project)
    settings.iconTint = ProjectIcon.storedTint(
      picking: slot,
      over: project.sharedSettingsSnapshot.confined?.iconTint,
    )
    setSettings(settings, for: project)
  }
}
