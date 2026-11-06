import MultishellAppCore
import SwiftUI

/// A settings page's glyph as the approved mockup drew it: thin round strokes
/// on a 16-unit grid, a dashed part where the page's mark has one.
struct SettingsPageGlyph: View {
  private static let strokeWidth: Double = 1.3
  private static let quarter: Double = 0.5523

  let page: SettingsPage

  var body: some View {
    Canvas { context, size in
      let scale = min(size.width, size.height) / GlyphGrid.side
      let transform = CGAffineTransform(scaleX: scale, y: scale)
      let style = StrokeStyle(
        lineWidth: Self.strokeWidth * scale,
        lineCap: .round,
        lineJoin: .round,
      )
      context.stroke(solid.applying(transform), with: .foreground, style: style)
      var dashed = style
      dashed.dash = [1.3 * scale, 1.7 * scale]
      context.stroke(dotted.applying(transform), with: .foreground, style: dashed)
    }
    .accessibilityHidden(true)
  }

  private var solid: Path {
    var path = Path()
    switch page {
    case .agents:
      path.addLines(
        points([6.5, 2, 7.7, 5.3, 11, 6.5, 7.7, 7.7, 6.5, 11, 5.3, 7.7, 2, 6.5, 5.3, 5.3])
      )
      path.closeSubpath()
      path.addLines(
        points([
          12, 9.5, 12.6, 11.1, 14.2, 11.7, 12.6, 12.3, 12, 13.9, 11.4, 12.3, 9.8, 11.7, 11.4, 11.1,
        ])
      )
      path.closeSubpath()

    case .appearance:
      appendPalette(to: &path)

    case .general:
      circle(&path, 8, 8, 2.3)
      for (from, to) in [
        (8.0, 1.5, 8.0, 3.5), (8, 12.5, 8, 14.5), (1.5, 8, 3.5, 8), (12.5, 8, 14.5, 8),
        (3.4, 3.4, 4.8, 4.8), (11.2, 11.2, 12.6, 12.6), (3.4, 12.6, 4.8, 11.2),
        (11.2, 4.8, 12.6, 3.4),
      ].map({ (CGPoint(x: $0.0, y: $0.1), CGPoint(x: $0.2, y: $0.3)) }) {
        path.move(to: from)
        path.addLine(to: to)
      }

    case .hooks:
      path.addLines(points([9.5, 1.5, 3, 9, 7.5, 9, 6.5, 14.5, 13, 7, 8.5, 7]))
      path.closeSubpath()

    case .integrations:
      circle(&path, 8, 3, 1.6)
      circle(&path, 3, 12.5, 1.6)
      circle(&path, 13, 12.5, 1.6)

    case .notifications:
      appendBell(to: &path)

    case .terminal:
      path.addRoundedRect(
        in: CGRect(x: 1.5, y: 2.5, width: 13, height: 11),
        cornerSize: CGSize(width: 2, height: 2),
      )
      path.addLines(points([4.5, 6, 6.5, 8, 4.5, 10]))
      path.move(to: CGPoint(x: 8.5, y: 10.5))
      path.addLine(to: CGPoint(x: 11.5, y: 10.5))

    case .worktrees:
      circle(&path, 4.5, 3.5, 1.6)
      circle(&path, 4.5, 12.5, 1.6)
      circle(&path, 11.5, 5, 1.6)
      path.move(to: CGPoint(x: 4.5, y: 5.1))
      path.addLine(to: CGPoint(x: 4.5, y: 10.9))
      path.move(to: CGPoint(x: 11.5, y: 6.6))
      path.addCurve(
        to: CGPoint(x: 4.5, y: 10.9),
        control1: CGPoint(x: 11.5, y: 9.6),
        control2: CGPoint(x: 4.5, y: 8.6),
      )
    }
    return path
  }

  /// Integrations' links between its three nodes; nothing on any other page.
  private var dotted: Path {
    var path = Path()
    guard page == .integrations else { return path }
    for line in [(7.2, 4.4, 3.8, 11.0), (8.8, 4.4, 12.2, 11), (4.6, 12.5, 11.4, 12.5)] {
      path.move(to: CGPoint(x: line.0, y: line.1))
      path.addLine(to: CGPoint(x: line.2, y: line.3))
    }
    return path
  }

  private func points(_ values: [Double]) -> [CGPoint] {
    stride(from: 0, to: values.count, by: 2).map { CGPoint(x: values[$0], y: values[$0 + 1]) }
  }

  private func circle(_ path: inout Path, _ x: Double, _ y: Double, _ radius: Double) {
    path.addEllipse(
      in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
    )
  }

  /// The bell, its dome as two quarter circles and its clapper a half circle.
  private func appendBell(to path: inout Path) {
    let dome = 4 * Self.quarter
    path.move(to: CGPoint(x: 4, y: 11))
    path.addLine(to: CGPoint(x: 4, y: 7))
    path.addCurve(
      to: CGPoint(x: 8, y: 3),
      control1: CGPoint(x: 4, y: 7 - dome),
      control2: CGPoint(x: 8 - dome, y: 3),
    )
    path.addCurve(
      to: CGPoint(x: 12, y: 7),
      control1: CGPoint(x: 8 + dome, y: 3),
      control2: CGPoint(x: 12, y: 7 - dome),
    )
    path.addLines(points([12, 7, 12, 11, 13.5, 12.5, 2.5, 12.5]))
    path.closeSubpath()
    let clapper = 1.5 * Self.quarter
    path.move(to: CGPoint(x: 6.5, y: 13.5))
    path.addCurve(
      to: CGPoint(x: 8, y: 15),
      control1: CGPoint(x: 6.5, y: 13.5 + clapper),
      control2: CGPoint(x: 8 - clapper, y: 15),
    )
    path.addCurve(
      to: CGPoint(x: 9.5, y: 13.5),
      control1: CGPoint(x: 8 + clapper, y: 15),
      control2: CGPoint(x: 9.5, y: 13.5 + clapper),
    )
  }

  /// The palette: a left half circle, a thumb notch, and three paint dots.
  private func appendPalette(to path: inout Path) {
    let rim = 6.5 * Self.quarter
    let notch = 2.5 * Self.quarter
    path.move(to: CGPoint(x: 8, y: 1.5))
    path.addCurve(
      to: CGPoint(x: 1.5, y: 8),
      control1: CGPoint(x: 8 - rim, y: 1.5),
      control2: CGPoint(x: 1.5, y: 8 - rim),
    )
    path.addCurve(
      to: CGPoint(x: 8, y: 14.5),
      control1: CGPoint(x: 1.5, y: 8 + rim),
      control2: CGPoint(x: 8 - rim, y: 14.5),
    )
    path.addCurve(
      to: CGPoint(x: 8.9, y: 13),
      control1: CGPoint(x: 9, y: 14.5),
      control2: CGPoint(x: 9.3, y: 13.7),
    )
    path.addCurve(
      to: CGPoint(x: 10, y: 11),
      control1: CGPoint(x: 8.3, y: 12),
      control2: CGPoint(x: 8.9, y: 11),
    )
    path.addLine(to: CGPoint(x: 12, y: 11))
    path.addCurve(
      to: CGPoint(x: 14.5, y: 8.5),
      control1: CGPoint(x: 12 + notch, y: 11),
      control2: CGPoint(x: 14.5, y: 8.5 + notch),
    )
    path.addCurve(
      to: CGPoint(x: 8, y: 1.5),
      control1: CGPoint(x: 14.5, y: 4.4),
      control2: CGPoint(x: 11.6, y: 1.5),
    )
    path.closeSubpath()
    circle(&path, 5, 7, 0.8)
    circle(&path, 8, 4.6, 0.8)
    circle(&path, 11, 6.6, 0.8)
  }
}
