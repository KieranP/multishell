import AppKit

/// A stroked state glyph animated by Core Animation in the render server: a
/// SwiftUI animation redraws its whole hosting view each frame.
final class AnimatedGlyphView: NSView {
  var motion: GlyphMotion {
    didSet {
      guard motion != oldValue else { return }
      glyph.removeAnimation(forKey: oldValue.animationKey)
      updatePath()
      startMotion()
    }
  }

  private let glyph = CAShapeLayer()

  // Flipped so the arcs lie as CIRunShape draws them, and the turn is clockwise.
  override var isFlipped: Bool { true }

  init(motion: GlyphMotion) {
    self.motion = motion
    super.init(frame: .zero)
    wantsLayer = true
    glyph.fillColor = nil
    glyph.lineCap = .round
    glyph.lineJoin = .round
    layer?.addSublayer(glyph)
  }

  required init?(coder: NSCoder) { nil }

  func stroke(color: NSColor, lineWidth: Double) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    glyph.strokeColor = color.cgColor
    glyph.lineWidth = lineWidth
    updatePath()
    CATransaction.commit()
  }

  // A glyph inside a row or a button: the click is theirs.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  // SwiftUI sizes the view by its frame, which need not ask for a layout pass.
  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    glyph.frame = bounds
    updatePath()
    CATransaction.commit()
  }

  // A sublayer added by hand keeps a scale of 1, so it would draw blurred on Retina.
  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    glyph.contentsScale = window?.backingScaleFactor ?? glyph.contentsScale
  }

  // A layer leaving its window loses its animations, so each arrival adds the motion.
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    glyph.removeAnimation(forKey: motion.animationKey)
    guard let window else { return }
    glyph.contentsScale = window.backingScaleFactor
    startMotion()
  }

  // SwiftUI strokes the view before it sizes it, and a zero rect inset is `CGRect.null`.
  private func updatePath() {
    glyph.path = bounds.isEmpty ? nil : motion.path(in: bounds, lineWidth: glyph.lineWidth)
  }

  private func startMotion() {
    guard window != nil else { return }
    let now = glyph.convertTime(CACurrentMediaTime(), from: nil)
    glyph.add(motion.animation(at: now), forKey: motion.animationKey)
  }
}
