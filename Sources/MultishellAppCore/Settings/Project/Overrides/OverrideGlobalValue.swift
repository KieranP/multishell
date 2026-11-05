import MultishellCore

/// What a project's settings table shows in its Global column: the value the
/// project follows while it has none of its own, and where that value is set.
public struct OverrideGlobalValue: Equatable, Sendable {
  enum Source: Equatable, Sendable {
    /// Read from the repository, as the default branch is, and said in its text.
    case detected
    /// Set for all projects.
    case global
    /// The repository's `.multishell.json` fills it.
    case repository
  }

  public let text: String
  private let source: Source
  /// The All Projects page that sets the value, which the cell opens; `nil`
  /// for a value set elsewhere, the sidebar's own menu or the repository.
  public let settingsSection: SettingsSection?

  /// Under the value, for a source other than the one the column is titled for.
  public var sourceNote: String? {
    switch source {
    case .detected, .global: nil
    case .repository: t("inherited.from-repository", SharedProjectSettings.fileName)
    }
  }

  /// `text` as stored, blank shown as `blankWord`: an empty cell reads as a
  /// value still loading.
  init(text: String, blankWord: String, source: Source, settingsSection: SettingsSection?) {
    self.text = text.isEmpty ? blankWord : text
    self.source = source
    self.settingsSection = source == .global ? settingsSection : nil
  }
}
