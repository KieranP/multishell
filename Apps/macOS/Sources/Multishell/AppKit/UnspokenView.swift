import AppKit

/// The base for the overlays catching an event SwiftUI has no gesture for.
/// None is an element of its own, or VoiceOver reads an unlabelled item.
class UnspokenView: NSView {
  override init(frame: NSRect) {
    super.init(frame: frame)
    setAccessibilityElement(false)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }
}
