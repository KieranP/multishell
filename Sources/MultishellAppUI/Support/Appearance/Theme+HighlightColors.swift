import AppKit
import MultishellAppCore
import MultishellCore

/// A highlight role's colour, from the theme's `file` section.
extension Theme {
  func color(for role: HighlightRole) -> NSColor {
    switch role {
    case .attribute: fileRGB(.attribute).nsColor
    case .comment: fileRGB(.comment).nsColor
    case .function: fileRGB(.function).nsColor
    case .keyword: fileRGB(.keyword).nsColor
    case .number: fileRGB(.number).nsColor
    case .plain: fileText
    case .punctuation: fileRGB(.punctuation).nsColor
    case .string: fileRGB(.string).nsColor
    case .type: fileRGB(.type).nsColor
    }
  }
}
