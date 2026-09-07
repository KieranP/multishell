import Foundation

/// A colour scheme for terminals and app chrome.
///
/// Colours are hex strings rather than a platform colour type so this stays
/// portable and Codable; each GUI converts once at the edge. That is also what
/// makes user-supplied theme files a drop-in later.
public struct Theme: Identifiable, Codable, Hashable, Sendable {
  public var id: String
  public var name: String
  public var isDark: Bool

  public var background: String
  public var foreground: String
  public var cursor: String
  public var selectionBackground: String

  /// The 16 ANSI colours, normal 0-7 then bright 8-15.
  public var ansi: [String]

  public init(
    id: String,
    name: String,
    isDark: Bool,
    background: String,
    foreground: String,
    cursor: String,
    selectionBackground: String,
    ansi: [String]
  ) {
    precondition(ansi.count == 16, "a theme needs exactly 16 ANSI colours")
    self.id = id
    self.name = name
    self.isDark = isDark
    self.background = background
    self.foreground = foreground
    self.cursor = cursor
    self.selectionBackground = selectionBackground
    self.ansi = ansi
  }

  /// Synthesized decoding would skip the precondition above, and the GUI
  /// indexes `ansi` directly, so a user theme file with the wrong number of
  /// colours is refused here and reported by `ThemeCatalog` rather than
  /// crashing the first view that draws with it.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let ansi = try c.decode([String].self, forKey: .ansi)
    guard ansi.count == 16 else {
      throw DecodingError.dataCorruptedError(
        forKey: .ansi, in: c,
        debugDescription: "a theme needs exactly 16 ANSI colours, found \(ansi.count)")
    }
    self.init(
      id: try c.decode(String.self, forKey: .id),
      name: try c.decode(String.self, forKey: .name),
      isDark: try c.decode(Bool.self, forKey: .isDark),
      background: try c.decode(String.self, forKey: .background),
      foreground: try c.decode(String.self, forKey: .foreground),
      cursor: try c.decode(String.self, forKey: .cursor),
      selectionBackground: try c.decode(String.self, forKey: .selectionBackground),
      ansi: ansi
    )
  }
}

extension Theme {
  public static let builtins: [Theme] = [.multishellDark, .multishellLight]

  public static let multishellDark = Theme(
    id: "multishell.dark",
    name: "Multishell Dark",
    isDark: true,
    background: "#121215",
    foreground: "#e4e4e7",
    cursor: "#e4e4e7",
    selectionBackground: "#2f4f7a",
    ansi: [
      "#26262b", "#ff6b60", "#6cc763", "#e5c07b",
      "#5aa9f8", "#bf5af2", "#64d2ff", "#c8c8cd",
      "#4a4a52", "#ff8b82", "#8fdb87", "#f0d49b",
      "#7fbdff", "#d191f5", "#8fe0ff", "#f2f2f5",
    ]
  )

  public static let multishellLight = Theme(
    id: "multishell.light",
    name: "Multishell Light",
    isDark: false,
    background: "#fbfbfa",
    foreground: "#26262b",
    cursor: "#26262b",
    selectionBackground: "#b9d5f5",
    ansi: [
      "#3c3c43", "#c7392f", "#3f8c38", "#9a7218",
      "#2f6fd0", "#8b3fbd", "#237f96", "#dcdcdf",
      "#6b6b73", "#e05548", "#54a84b", "#b98d28",
      "#4a8ae8", "#a55dd4", "#3399b0", "#f7f7f8",
    ]
  )
}
