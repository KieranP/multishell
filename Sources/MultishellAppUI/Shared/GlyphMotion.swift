import MultishellServices
import QuartzCore
import SwiftUI

/// What an `AnimatedGlyphView` strokes and how Core Animation moves it.
enum GlyphMotion {
  /// Working's arc, a fifth of the ring, going round its track.
  case orbit
  /// Waiting's ring, fading out and back.
  case pulse
  /// The running ring's four arcs, turning clockwise.
  case turn

  private static let orbitArcShare = 0.2
  private static let orbitDuration: CFTimeInterval = 1.1
  private static let pulseDuration: CFTimeInterval = 0.9
  private static let pulseFaintestOpacity: Float = 0.3
  private static let turnDuration: CFTimeInterval = 1

  var animationKey: String {
    switch self {
    case .orbit: "orbit"
    case .pulse: "pulse"
    case .turn: "turn"
    }
  }

  /// One whole movement, a pulse being out and back.
  var cycle: CFTimeInterval {
    switch self {
    case .orbit: Self.orbitDuration
    case .pulse: Self.pulseDuration * 2
    case .turn: Self.turnDuration
    }
  }

  func path(in rect: CGRect, lineWidth: Double) -> CGPath {
    let inset = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
    switch self {
    case .orbit:
      let path = CGMutablePath()
      let start = -Double.pi / 2
      path.addArc(
        center: CGPoint(x: inset.midX, y: inset.midY),
        radius: inset.width / 2,
        startAngle: start,
        endAngle: start + 2 * Double.pi * Self.orbitArcShare,
        clockwise: false,
      )
      return path

    case .pulse:
      return CGPath(ellipseIn: inset, transform: nil)

    case .turn:
      return CIRunShape(status: .running).path(in: rect).cgPath
    }
  }

  /// Begun on the last whole cycle before `layerTime`, so glyphs added at
  /// different moments move in step.
  func animation(at layerTime: CFTimeInterval) -> CABasicAnimation {
    let animation = unphasedAnimation()
    animation.beginTime = layerTime - layerTime.truncatingRemainder(dividingBy: cycle)
    return animation
  }

  private func unphasedAnimation() -> CABasicAnimation {
    switch self {
    case .orbit:
      return turning(every: Self.orbitDuration)

    case .pulse:
      let pulse = CABasicAnimation(keyPath: "opacity")
      pulse.fromValue = 1
      pulse.toValue = Self.pulseFaintestOpacity
      pulse.duration = Self.pulseDuration
      pulse.autoreverses = true
      pulse.repeatCount = .infinity
      pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      return pulse

    case .turn:
      return turning(every: Self.turnDuration)
    }
  }

  private func turning(every duration: CFTimeInterval) -> CABasicAnimation {
    let turn = CABasicAnimation(keyPath: "transform.rotation.z")
    turn.byValue = 2 * Double.pi
    turn.duration = duration
    turn.repeatCount = .infinity
    return turn
  }
}
