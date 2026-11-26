import MultishellCore
import SwiftUI

/// A state dot as an image, for an AppKit menu's row, which draws a title and
/// an image and nothing else. `nil` state is a clear square, keeping names aligned.
@MainActor
enum StateDotImage {
  private struct Key: Hashable {
    let state: SessionState?
    let frame: Int
    let theme: Theme
    let scale: CGFloat
  }

  /// The working dot's turn, drawn as this many still frames shown in order.
  private static let workingFrameCount = 16
  static var workingFrameInterval: TimeInterval {
    GlyphMotion.orbit.cycle / Double(workingFrameCount)
  }

  /// Keyed by theme and scale too, as `AgentMarkImage` is by scale.
  private static var rendered: [Key: NSImage] = [:]

  /// `frame` counts round the working dot's turn; other states have one.
  static func image(for state: SessionState?, theme: Theme, frame: Int = 0) -> NSImage? {
    let turnFrame = state == .running ? frame % workingFrameCount : 0
    let key = Key(state: state, frame: turnFrame, theme: theme, scale: NSScreen.mainBackingScale)
    if let cached = rendered[key] { return cached }
    let turn = Double(turnFrame) / Double(workingFrameCount)
    let renderer = ImageRenderer(content: content(for: state, turn: turn, theme: theme))
    renderer.scale = key.scale
    guard let image = renderer.nsImage else { return nil }
    rendered[key] = image
    return image
  }

  @ViewBuilder
  private static func content(for state: SessionState?, turn: Double, theme: Theme) -> some View {
    ZStack {
      Color.clear
      if let state {
        StateDot(
          state: state,
          theme: theme,
          palette: theme.header,
          isAnimated: false,
          stillTurn: turn,
        )
      }
    }
    .frame(width: UIMetrics.menuMarkSide, height: UIMetrics.menuMarkSide)
  }
}
