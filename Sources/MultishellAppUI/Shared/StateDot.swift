import MultishellAppCore
import MultishellCore
import SwiftUI

/// A session state's colour in its `StateDotKind`, the one mark a row, a
/// lane, a corner badge and a worker share.
struct StateDot: View {
  /// Waiting's centre dot, as a share of the ring it sits in.
  private static let centreShare = 0.36
  /// Failed's square, smaller than the dot so its corners weigh as much as a circle.
  private static let squareSideShare = 0.86
  private static let squareCornerShare = 0.18
  /// Working's track, faint enough that the arc on it reads as what moves.
  private static let orbitTrackOpacity = 0.3

  let state: SessionState
  let theme: Theme
  /// What the dot sits on, for idle's grey.
  let palette: AreaPalette
  var diameter: Double = 7
  /// Off where the dot names a state rather than reports one, as an empty column's header.
  var isAnimated = true

  @Environment(\.accessibilityReduceMotion) private var reducesMotion

  private var lineWidth: Double { max(1.2, diameter * 0.18) }
  /// Heavier than the other rings: working's arc covers a fifth of its circle,
  /// so at the rings' weight it read as a hairline.
  private var orbitLineWidth: Double { max(1.6, diameter * 0.24) }
  private var moves: Bool { isAnimated && !reducesMotion }

  var body: some View {
    let color = theme.color(for: state, on: palette)
    glyph(for: StateDotKind(state), color: color)
      .frame(width: diameter, height: diameter)
  }

  @ViewBuilder
  private func glyph(for kind: StateDotKind, color: Color) -> some View {
    switch kind {
    case .filled:
      Circle().fill(color)

    case .hollowRing:
      Circle().strokeBorder(color, lineWidth: lineWidth)

    case .orbitingArc:
      ZStack {
        Circle().strokeBorder(color.opacity(Self.orbitTrackOpacity), lineWidth: orbitLineWidth)
        if moves {
          AnimatedGlyph(motion: .orbit, color: color, lineWidth: orbitLineWidth)
        } else {
          StillGlyphShape(motion: .orbit, lineWidth: orbitLineWidth)
            .stroke(color, style: StrokeStyle(lineWidth: orbitLineWidth, lineCap: .round))
        }
      }

    case .ringAroundDot:
      ZStack {
        if moves {
          AnimatedGlyph(motion: .pulse, color: color, lineWidth: lineWidth)
        } else {
          Circle().strokeBorder(color, lineWidth: lineWidth)
        }
        Circle()
          .fill(color)
          .frame(width: diameter * Self.centreShare, height: diameter * Self.centreShare)
      }

    case .square:
      let side = diameter * Self.squareSideShare
      RoundedRectangle(cornerRadius: side * Self.squareCornerShare)
        .fill(color)
        .frame(width: side, height: side)
    }
  }
}
