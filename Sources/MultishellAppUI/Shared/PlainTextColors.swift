import AppKit
import SwiftUI

/// A plain text field's colours inside a themed area; without them it takes the
/// system's, as the settings window, outside the theme, wants.
struct PlainTextColors {
  let text: NSColor
  let selection: NSColor
  let placeholder: Color
}
