import AppKit
import MultishellAppCore
import MultishellCore

/// A highlight role's colour, from the theme's own palette, so a user theme
/// recolours highlighting with nothing new to write.
extension Theme {
  func color(for role: HighlightRole) -> NSColor {
    switch role {
    case .attribute, .function: ansiRGB(.blue).nsColor()
    case .comment: foregroundRGB.nsColor(alpha: Self.tertiaryTextOpacity)
    case .keyword: ansiRGB(.magenta).nsColor()
    case .number: ansiRGB(.yellow).nsColor()
    case .plain: fileText
    case .punctuation: foregroundRGB.nsColor(alpha: Self.secondaryTextOpacity)
    case .string: ansiRGB(.green).nsColor()
    case .type: ansiRGB(.cyan).nsColor()
    }
  }
}
