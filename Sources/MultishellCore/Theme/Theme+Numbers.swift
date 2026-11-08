/// The theme's numbers: how far unfocused panes fade and how big the state
/// dots draw, each the theme's own where it sets one, else its base theme's.
extension Theme {
  /// Anything less would be a pane nobody can read, which looks broken
  /// rather than unfocused.
  static let minimumInactivePaneOpacity = 0.25
  /// Under 1 a ring's stroke fills the dot; past 1.4 a worktree's dot
  /// outgrows the sidebar's glyph column at the smallest UI font.
  static let stateDotScaleRange = 1.0...1.4

  /// What every pane but the focused one draws at, faded towards the
  /// terminal's background, clamped before a pane looks broken.
  public var inactivePaneOpacity: Double {
    resolvedNumber(\.ownInactivePaneOpacity, clampedTo: Self.minimumInactivePaneOpacity...1)
  }

  /// What every state dot's diameter is multiplied by, and a file tab's change dot.
  public var stateDotScale: Double {
    resolvedNumber(\.ownStateDotScale, clampedTo: Self.stateDotScaleRange)
  }

  private static func finite(_ number: Double?) -> Double? {
    number.flatMap { $0.isFinite ? $0 : nil }
  }

  /// The theme's own finite number, else its base's. Neither setting one is 1,
  /// which leaves panes unfaded and dots at their design size.
  private func resolvedNumber(
    _ own: KeyPath<Theme, Double?>,
    clampedTo range: ClosedRange<Double>,
  ) -> Double {
    let number = Self.finite(self[keyPath: own]) ?? Self.finite(base[keyPath: own]) ?? 1
    return number.clamped(to: range)
  }
}
