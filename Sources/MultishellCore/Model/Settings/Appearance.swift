/// App-wide look, separate from `ProjectSettings` because it is not per-repo.
public struct Appearance: Codable, Hashable, Sendable {
  /// The terminal font keeps the keys it was saved under before the rename.
  private enum CodingKeys: String, CodingKey {
    case themeID
    case terminalFontName = "fontName"
    case terminalFontSize = "fontSize"
    case uiFontName
    case uiFontSize
    case fileFontName
    case fileFontSize
  }

  static let defaultTerminalFontSize = 13.0
  static let defaultUIFontSize = 13.0
  /// What file tabs drew at the default UI size before they had their own.
  static let defaultFileFontSize = 12.0
  public static let terminalFontSizes = 9.0...24.0
  public static let uiFontSizes = 10.0...18.0
  public static let fileFontSizes = 9.0...24.0

  public internal(set) var themeID: Theme.ID
  /// `nil` uses the platform's default monospace face.
  public internal(set) var terminalFontName: String?
  public internal(set) var terminalFontSize: Double
  /// The family of every chrome text; `nil` uses the system font.
  public internal(set) var uiFontName: String?
  /// Sidebar, tabs and header. Every chrome measurement scales from it.
  public internal(set) var uiFontSize: Double
  /// A file tab's text; `nil` uses the platform's default monospace face.
  public internal(set) var fileFontName: String?
  public internal(set) var fileFontSize: Double

  init(
    themeID: Theme.ID = Theme.multishellDark.id,
    terminalFontName: String? = nil,
    terminalFontSize: Double = Self.defaultTerminalFontSize,
    uiFontName: String? = nil,
    uiFontSize: Double = Self.defaultUIFontSize,
    fileFontName: String? = nil,
    fileFontSize: Double = Self.defaultFileFontSize,
  ) {
    self.themeID = themeID
    self.terminalFontName = terminalFontName
    self.terminalFontSize = terminalFontSize
    self.uiFontName = uiFontName
    self.uiFontSize = uiFontSize
    self.fileFontName = fileFontName
    self.fileFontSize = fileFontSize
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    themeID = try container.decode(Theme.ID.self, forKey: .themeID, or: Theme.multishellDark.id)
    terminalFontName = try container.decodeIfPresent(String.self, forKey: .terminalFontName)
    terminalFontSize = try container.decode(
      Double.self,
      forKey: .terminalFontSize,
      or: Self.defaultTerminalFontSize,
    )
    uiFontName = try container.decodeIfPresent(String.self, forKey: .uiFontName)
    uiFontSize = try container.decode(Double.self, forKey: .uiFontSize, or: Self.defaultUIFontSize)
    fileFontName = try container.decodeIfPresent(String.self, forKey: .fileFontName)
    fileFontSize = try container.decode(
      Double.self,
      forKey: .fileFontSize,
      or: Self.defaultFileFontSize,
    )
  }

  /// Falls back to the built-in dark theme when a saved theme id no longer
  /// resolves, so deleting a theme file cannot leave the app unpaintable.
  public func theme(from themes: [Theme] = Theme.builtins) -> Theme {
    themes.first { $0.id == themeID } ?? .multishellDark
  }
}
