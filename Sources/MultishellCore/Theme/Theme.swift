/// A colour scheme for terminals and app chrome. Hex strings, not a platform
/// colour type, so the core imports no UI framework; see Docs/design/appearance.md.
public struct Theme: Identifiable, Codable, Hashable, Sendable {
  /// Anything less would be a pane nobody can read, which looks broken
  /// rather than unfocused.
  static let minimumInactivePaneOpacity = 0.25

  public static let ansiSlotCount = 16

  public internal(set) var id: String
  public internal(set) var name: String
  public internal(set) var isDark: Bool

  public internal(set) var background: String
  public internal(set) var foreground: String
  public internal(set) var cursor: String
  public internal(set) var selectionBackground: String

  /// The 16 ANSI colours, normal 0-7 then bright 8-15.
  public internal(set) var ansi: [String]

  /// The line round the pane keystrokes go to. `""` is no line, `nil`
  /// follows `selectionBackground`; see `focusRingRGB`.
  var focusRing: String?
  /// What every pane but the focused one draws at, faded towards the
  /// theme's own background. `1` fades nothing.
  public internal(set) var inactivePaneOpacity: Double

  init(
    id: String,
    name: String,
    isDark: Bool,
    background: String,
    foreground: String,
    cursor: String,
    selectionBackground: String,
    ansi: [String],
    focusRing: String?,
    inactivePaneOpacity: Double,
  ) {
    precondition(
      ansi.count == Self.ansiSlotCount,
      "a theme needs exactly \(Self.ansiSlotCount) ANSI colours",
    )
    self.id = id
    self.name = name
    self.isDark = isDark
    self.background = background
    self.foreground = foreground
    self.cursor = cursor
    self.selectionBackground = selectionBackground
    self.ansi = ansi
    self.focusRing = focusRing
    self.inactivePaneOpacity = Self.usableOpacity(inactivePaneOpacity)
  }

  /// Synthesized decoding skips the precondition, and the GUI indexes `ansi`
  /// directly, so a wrong count is refused here rather than crashing a view.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let ansi = try container.decode([String].self, forKey: .ansi)
    guard ansi.count == Self.ansiSlotCount else {
      throw DecodingError.dataCorruptedError(
        forKey: .ansi,
        in: container,
        debugDescription:
          "a theme needs exactly \(Self.ansiSlotCount) ANSI colours, found \(ansi.count)",
      )
    }
    let opacity = container.decodeTolerantly(Double.self, forKey: .inactivePaneOpacity)
    self.init(
      id: try container.decode(String.self, forKey: .id),
      name: try container.decode(String.self, forKey: .name),
      isDark: try container.decode(Bool.self, forKey: .isDark),
      background: try container.decode(String.self, forKey: .background),
      foreground: try container.decode(String.self, forKey: .foreground),
      cursor: try container.decode(String.self, forKey: .cursor),
      selectionBackground: try container.decode(String.self, forKey: .selectionBackground),
      ansi: ansi,
      focusRing: container.decodeTolerantly(String.self, forKey: .focusRing),
      inactivePaneOpacity: opacity ?? 1,
    )
  }

  private static func usableOpacity(_ value: Double) -> Double {
    guard value.isFinite else { return 1 }
    return value.clamped(to: minimumInactivePaneOpacity...1)
  }
}
