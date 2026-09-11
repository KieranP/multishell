import AppKit
import GhosttyTerminal

/// Metal-backed surfaces need an explicit `fitToSize` after any layout change.
@MainActor
final class SurfaceContainerView: NSView {
  private let surface: TerminalView

  init(surface: TerminalView) {
    self.surface = surface
    super.init(frame: .zero)
    surface.autoresizingMask = [.width, .height]
    addSubview(surface)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func layout() {
    super.layout()
    surface.frame = bounds
    surface.fitToSize()
  }

  /// A click anywhere in the container is a click on the terminal, or one on
  /// the hosting layer leaves focus there and the Edit menu disabled.
  override func mouseDown(with event: NSEvent) {
    surface.takeFirstResponder()
    super.mouseDown(with: event)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    surface.setSurfaceVisible(window != nil)
  }
}
