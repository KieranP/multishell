/// App-wide look, separate from `ProjectSettings` because it is not per-repo.
public struct Appearance: Codable, Hashable, Sendable {
  public internal(set) var themeID: Theme.ID
  /// `nil` uses the platform's default monospace face.
  public internal(set) var terminalFontName: String?
  public internal(set) var terminalFontSize: Double
  /// Sidebar, tabs and header. Every chrome measurement scales from it.
  public internal(set) var uiFontSize: Double

  static let defaultTerminalFontSize = 13.0
  static let defaultUIFontSize = 13.0
  public static let terminalFontSizes = 9.0...24.0
  public static let uiFontSizes = 10.0...18.0

  init(
    themeID: Theme.ID = Theme.multishellDark.id,
    terminalFontName: String? = nil,
    terminalFontSize: Double = Appearance.defaultTerminalFontSize,
    uiFontSize: Double = Appearance.defaultUIFontSize
  ) {
    self.themeID = themeID
    self.terminalFontName = terminalFontName
    self.terminalFontSize = terminalFontSize
    self.uiFontSize = uiFontSize
  }

  /// The terminal font keeps the keys it was saved under before the rename.
  private enum CodingKeys: String, CodingKey {
    case themeID
    case terminalFontName = "fontName"
    case terminalFontSize = "fontSize"
    case uiFontSize
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    themeID = try container.decode(Theme.ID.self, forKey: .themeID, or: Theme.multishellDark.id)
    terminalFontName = try container.decodeIfPresent(String.self, forKey: .terminalFontName)
    terminalFontSize = try container.decode(
      Double.self, forKey: .terminalFontSize, or: Self.defaultTerminalFontSize)
    uiFontSize = try container.decode(Double.self, forKey: .uiFontSize, or: Self.defaultUIFontSize)
  }

  /// Falls back to the built-in dark theme when a saved theme id no longer
  /// resolves, so deleting a theme file cannot leave the app unpaintable.
  public func theme(from catalogue: [Theme] = Theme.builtins) -> Theme {
    catalogue.first { $0.id == themeID } ?? .multishellDark
  }
}
