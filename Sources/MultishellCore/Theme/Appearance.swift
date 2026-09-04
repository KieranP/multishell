import Foundation

/// App-wide look, separate from `ProjectSettings` because it is not per-repo.
public struct Appearance: Codable, Hashable, Sendable {
  public var themeID: Theme.ID
  /// `nil` uses the platform's default monospace face.
  public var fontName: String?
  /// Terminal text.
  public var fontSize: Double
  /// Sidebar, tabs and header. Every chrome measurement scales from it.
  public var uiFontSize: Double

  public static let defaultFontSize = 13.0
  public static let defaultUIFontSize = 13.0

  public init(
    themeID: Theme.ID = Theme.multishellDark.id,
    fontName: String? = nil,
    fontSize: Double = Appearance.defaultFontSize,
    uiFontSize: Double = Appearance.defaultUIFontSize
  ) {
    self.themeID = themeID
    self.fontName = fontName
    self.fontSize = fontSize
    self.uiFontSize = uiFontSize
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    themeID = try c.decodeIfPresent(Theme.ID.self, forKey: .themeID) ?? Theme.multishellDark.id
    fontName = try c.decodeIfPresent(String.self, forKey: .fontName)
    fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? Self.defaultFontSize
    uiFontSize = try c.decodeIfPresent(Double.self, forKey: .uiFontSize) ?? Self.defaultUIFontSize
  }

  /// Falls back to the built-in dark theme when a saved theme id no longer
  /// resolves, so deleting a theme file cannot leave the app unpaintable.
  public func theme(from catalogue: [Theme] = Theme.builtins) -> Theme {
    catalogue.first { $0.id == themeID } ?? .multishellDark
  }
}
