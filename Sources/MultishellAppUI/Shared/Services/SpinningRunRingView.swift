import AppKit
import MultishellServices
import SwiftUI

/// The running ring, turned by Core Animation in the render server: a SwiftUI
/// rotation redraws its whole hosting view each frame.
final class SpinningRunRingView: NSView {
  private static let turnKey = "turn"
  private static let turnDuration: CFTimeInterval = 1

  private let ring = CAShapeLayer()

  // Flipped so the arcs lie as CIRunShape draws them, and the turn is clockwise.
  override var isFlipped: Bool { true }

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    ring.fillColor = nil
    ring.lineCap = .round
    ring.lineJoin = .round
    layer?.addSublayer(ring)
  }

  required init?(coder: NSCoder) { nil }

  func stroke(color: NSColor, lineWidth: Double) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    ring.strokeColor = color.cgColor
    ring.lineWidth = lineWidth
    CATransaction.commit()
  }

  // A glyph inside a row's button: the click is the button's.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  // SwiftUI sizes the view by its frame, which need not ask for a layout pass.
  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    ring.frame = bounds
    ring.path = CIRunShape(status: .running).path(in: bounds).cgPath
    CATransaction.commit()
  }

  // A sublayer added by hand keeps a scale of 1, so it would draw blurred on Retina.
  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    ring.contentsScale = window?.backingScaleFactor ?? ring.contentsScale
  }

  // A layer leaving its window loses its animations, so each arrival adds the turn.
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    ring.removeAnimation(forKey: Self.turnKey)
    guard let window else { return }
    ring.contentsScale = window.backingScaleFactor
    let turn = CABasicAnimation(keyPath: "transform.rotation.z")
    turn.byValue = 2 * Double.pi
    turn.duration = Self.turnDuration
    turn.repeatCount = .infinity
    ring.add(turn, forKey: Self.turnKey)
  }
}
