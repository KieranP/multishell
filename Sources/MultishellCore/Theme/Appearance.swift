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
    let container = try decoder.container(keyedBy: CodingKeys.self)
    themeID = try container.decode(Theme.ID.self, forKey: .themeID, or: Theme.multishellDark.id)
    fontName = try container.decodeIfPresent(String.self, forKey: .fontName)
    fontSize = try container.decode(Double.self, forKey: .fontSize, or: Self.defaultFontSize)
    uiFontSize = try container.decode(Double.self, forKey: .uiFontSize, or: Self.defaultUIFontSize)
  }

  /// Falls back to the built-in dark theme when a saved theme id no longer
  /// resolves, so deleting a theme file cannot leave the app unpaintable.
  public func theme(from catalogue: [Theme] = Theme.builtins) -> Theme {
    catalogue.first { $0.id == themeID } ?? .multishellDark
  }
}
