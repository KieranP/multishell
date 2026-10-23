import AppKit
import MultishellCore

/// A file tab's colours, for AppKit, from the theme's `file` section.
extension Theme {
  var fileBackground: NSColor { fileRGB(.background).nsColor }
  var fileText: NSColor { fileRGB(.text).nsColor }
  var removedFileText: NSColor { fileRGB(.removedText).nsColor }
  var lineNumberText: NSColor { fileRGB(.lineNumber).nsColor }
  /// Between a split's two sides.
  var splitDividerColor: NSColor { fileRGB(.divider).nsColor }
  var addedLineTint: NSColor { fileRGB(.addedBackground).nsColor }
  var removedLineTint: NSColor { fileRGB(.removedBackground).nsColor }
  /// The words a line changed, over its line's tint, as GitHub marks them.
  var addedPartTint: NSColor { fileRGB(.addedWordBackground).nsColor }
  var removedPartTint: NSColor { fileRGB(.removedWordBackground).nsColor }
  var addedLineMark: NSColor { fileRGB(.added).nsColor }
  var removedLineMark: NSColor { fileRGB(.removed).nsColor }
  /// A split side's row across from a change on the other side.
  var paddingRowTint: NSColor { fileRGB(.paddingBackground).nsColor }
  var findMatchTint: NSColor { fileRGB(.findMatch).nsColor }
  var fileSelection: NSColor { fileRGB(.selectionBackground).nsColor }
  /// The file's own text, softened: no theme key, as every theme's text reads
  /// against both its tints.
  var steppedChangeBorder: NSColor { fileText.withAlphaComponent(0.55) }
}
