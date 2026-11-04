import SwiftUI

struct AnimatedGlyph: NSViewRepresentable {
  let motion: GlyphMotion
  let color: Color
  let lineWidth: Double

  func makeNSView(context: Context) -> AnimatedGlyphView {
    AnimatedGlyphView(motion: motion)
  }

  func updateNSView(_ view: AnimatedGlyphView, context: Context) {
    view.motion = motion
    view.stroke(color: NSColor(color), lineWidth: lineWidth)
  }
}
