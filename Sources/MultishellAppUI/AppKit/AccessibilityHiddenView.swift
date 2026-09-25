import AppKit

/// The base for the AppKit overlays laid under SwiftUI. None is an element
/// of its own, or VoiceOver reads an unlabelled item.
class AccessibilityHiddenView: NSView {
  override init(frame: NSRect) {
    super.init(frame: frame)
    setAccessibilityElement(false)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }
}
