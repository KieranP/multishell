import AppKit
import MultishellCore

/// A file tab's colours, for AppKit. The tints are light, green strings on green
/// losing contrast; see Docs/design/files.md.
extension Theme {
  private static let darkLineTintAlpha = 0.12
  private static let lightLineTintAlpha = 0.10
  /// The words a line changed, over its line's tint, as GitHub marks them.
  private static let darkPartTintAlpha = 0.24
  private static let lightPartTintAlpha = 0.20

  private var lineTintAlpha: Double { isDark ? Self.darkLineTintAlpha : Self.lightLineTintAlpha }
  private var partTintAlpha: Double { isDark ? Self.darkPartTintAlpha : Self.lightPartTintAlpha }

  var fileBackground: NSColor { backgroundRGB.nsColor() }
  var fileText: NSColor { foregroundRGB.nsColor(alpha: Self.primaryTextOpacity) }
  /// A removed line's text, held back a little as the prototype draws it.
  var removedFileText: NSColor { foregroundRGB.nsColor(alpha: 0.78) }
  var lineNumberText: NSColor { foregroundRGB.nsColor(alpha: Self.tertiaryTextOpacity) }
  /// Between a split's two sides, fainter than the numbers beside it.
  var splitDividerColor: NSColor { foregroundRGB.nsColor(alpha: 0.25) }
  var addedLineTint: NSColor { ansiRGB(.green).nsColor(alpha: lineTintAlpha) }
  var removedLineTint: NSColor { ansiRGB(.red).nsColor(alpha: lineTintAlpha) }
  var addedPartTint: NSColor { ansiRGB(.green).nsColor(alpha: partTintAlpha) }
  var removedPartTint: NSColor { ansiRGB(.red).nsColor(alpha: partTintAlpha) }
  var addedLineMark: NSColor { ansiRGB(.green).nsColor() }
  var removedLineMark: NSColor { ansiRGB(.red).nsColor() }
  /// A split side's row across from a change on the other side.
  var paddingRowTint: NSColor { foregroundRGB.nsColor(alpha: 0.04) }
  var findMatchTint: NSColor { ansiRGB(.yellow).nsColor(alpha: 0.35) }
}
