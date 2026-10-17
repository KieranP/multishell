/// A colour scheme as a theme file writes it, every colour optional; one left
/// out is its base theme's, see `Theme+Colors` and Docs/design/appearance.md.
public struct Theme: Identifiable, Decodable, Hashable, Sendable {
  private enum CodingKeys: String, CodingKey {
    case fileColors = "file"
    case id
    case isDark = "is_dark"
    case name
    case interfaceColors = "ui"
    case terminal
  }

  public static let ansiSlotCount = 16

  /// What the `ansi` and `project_icons` maps are keyed by, in palette order:
  /// normal 0-7 then bright 8-15.
  private static let paletteNames = [
    "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
    "bright_black", "bright_red", "bright_green", "bright_yellow",
    "bright_blue", "bright_magenta", "bright_cyan", "bright_white",
  ]

  private static let ansiKey = RawCodingKey(stringValue: "ansi")
  private static let inactivePaneOpacityKey = RawCodingKey(stringValue: "inactive_pane_opacity")
  private static let projectIconsKey = RawCodingKey(stringValue: "project_icons")
  private static let agentMarksKey = RawCodingKey(stringValue: "agent_marks")

  public let id: String
  public let name: String
  /// Picks the base theme the rest falls back on, and the window's appearance.
  public let isDark: Bool

  var terminalColors: [TerminalColorKey: String]
  /// Keyed by palette slot.
  var ansiColors: [Int: String]
  var ownInactivePaneOpacity: Double?
  var fileColors: [FileColorKey: String]
  var interfaceColors: [InterfaceSection: [InterfaceColorKey: String]]
  /// Keyed by palette slot, the number a project's tint is saved as.
  var projectIconColors: [Int: String]
  /// Keyed by agent id; `""` draws the mark in the text around it.
  var agentMarkColors: [String: String]

  /// A colour of the wrong type, a key nothing reads and a section that is
  /// not an object are all skipped: a typo should cost that colour, not the theme.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try Self.refuseFlatShape(decoder)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    isDark = container.decodeTolerantly(Bool.self, forKey: .isDark) ?? true

    let terminal = try? container.nestedContainer(keyedBy: RawCodingKey.self, forKey: .terminal)
    terminalColors = Self.colors(of: TerminalColorKey.allCases, in: terminal)
    ansiColors = Self.paletteColors(in: terminal, at: Self.ansiKey)
    ownInactivePaneOpacity = terminal?.decodeTolerantly(
      Double.self,
      forKey: Self.inactivePaneOpacityKey,
    )

    let file = try? container.nestedContainer(keyedBy: RawCodingKey.self, forKey: .fileColors)
    fileColors = Self.colors(of: FileColorKey.allCases, in: file)

    let interface = try? container.nestedContainer(
      keyedBy: RawCodingKey.self,
      forKey: .interfaceColors,
    )
    var interfaceColors: [InterfaceSection: [InterfaceColorKey: String]] = [:]
    for section in InterfaceSection.allCases {
      let entry = try? interface?.nestedContainer(
        keyedBy: RawCodingKey.self,
        forKey: RawCodingKey(stringValue: section.rawValue),
      )
      let colors = Self.colors(of: section.colorKeys, in: entry)
      if !colors.isEmpty { interfaceColors[section] = colors }
    }
    self.interfaceColors = interfaceColors
    projectIconColors = Self.paletteColors(in: interface, at: Self.projectIconsKey)
    let marks = try? interface?.nestedContainer(
      keyedBy: RawCodingKey.self,
      forKey: Self.agentMarksKey,
    )
    var agentMarkColors: [String: String] = [:]
    for key in marks?.allKeys ?? [] {
      agentMarkColors[key.stringValue] = marks?.decodeTolerantly(String.self, forKey: key)
    }
    self.agentMarkColors = agentMarkColors
  }

  /// A file from before sections would otherwise load as its base theme under
  /// its own name, which reads as the theme having been ignored.
  private static func refuseFlatShape(_ decoder: any Decoder) throws {
    let file = try decoder.container(keyedBy: RawCodingKey.self)
    let flatKeys = ["ansi", "background", "foreground"].map(RawCodingKey.init(stringValue:))
    guard flatKeys.contains(where: file.contains) else { return }
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: [],
        debugDescription: "written before themes had sections; see the examples folder",
      )
    )
  }

  private static func colors<Key: RawRepresentable<String> & Hashable>(
    of keys: [Key],
    in container: KeyedDecodingContainer<RawCodingKey>?,
  ) -> [Key: String] {
    var colors: [Key: String] = [:]
    for key in keys {
      colors[key] = container?.decodeTolerantly(
        String.self,
        forKey: RawCodingKey(stringValue: key.rawValue),
      )
    }
    return colors
  }

  private static func paletteColors(
    in container: KeyedDecodingContainer<RawCodingKey>?,
    at key: RawCodingKey,
  ) -> [Int: String] {
    let map = try? container?.nestedContainer(keyedBy: RawCodingKey.self, forKey: key)
    var colors: [Int: String] = [:]
    for (slot, name) in paletteNames.enumerated() {
      colors[slot] = map?.decodeTolerantly(String.self, forKey: RawCodingKey(stringValue: name))
    }
    return colors
  }
}
