import MultishellServices
import SwiftUI

/// A CI status as the design's strokes in a 16-unit square, scaled to the
/// frame: a ring holding a check, a cross, a pause or a slash.
struct CIRunShape: Shape {
  /// Where a running ring breaks, in degrees from three o'clock: four arcs.
  private static let runningArcs: [(start: Double, end: Double)] = [
    (-90, 0), (17.9, 72.1), (107.9, 162.1), (193, 242.6),
  ]

  let status: CIRunStatus

  func path(in rect: CGRect) -> Path {
    let unit = min(rect.width, rect.height) / 16
    func point(_ x: Double, _ y: Double) -> CGPoint {
      CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
    }
    var path = Path()
    func stroke(_ from: (Double, Double), _ to: (Double, Double)) {
      path.move(to: point(from.0, from.1))
      path.addLine(to: point(to.0, to.1))
    }
    guard status != .running else {
      // A move to each arc's start: an arc otherwise joins the last with a line.
      for arc in Self.runningArcs {
        let start = Angle.degrees(arc.start).radians
        path.move(to: point(8 + 6.5 * cos(start), 8 + 6.5 * sin(start)))
        path.addRelativeArc(
          center: point(8, 8),
          radius: 6.5 * unit,
          startAngle: .degrees(arc.start),
          delta: .degrees(arc.end - arc.start),
        )
      }
      return path
    }
    path.addEllipse(
      in: CGRect(origin: point(1.5, 1.5), size: CGSize(width: 13 * unit, height: 13 * unit))
    )
    switch status {
    case .passed:
      path.move(to: point(5.3, 8.3))
      path.addLine(to: point(7.1, 10))
      path.addLine(to: point(10.7, 6.2))

    case .failed:
      stroke((5.8, 5.8), (10.2, 10.2))
      stroke((10.2, 5.8), (5.8, 10.2))

    case .onHold:
      stroke((6.4, 5.6), (6.4, 10.4))
      stroke((9.6, 5.6), (9.6, 10.4))

    case .cancelled:
      stroke((3.6, 12.4), (12.4, 3.6))

    case .running:
      break
    }
    return path
  }
}
