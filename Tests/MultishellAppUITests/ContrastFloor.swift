/// How far a mark must stand off its ground at least, as the design picks were
/// judged (2026-11-05), so a theme edit cannot fade one past readable.
enum ContrastFloor {
  /// Multishell Light's 6% wash: a hover wash, a lit square, a button's edge.
  static let faintestReadable = 1.1
  /// Multishell Light's 18% selection wash, which carries a row with no outline.
  static let faintestSelection = 1.25
}
