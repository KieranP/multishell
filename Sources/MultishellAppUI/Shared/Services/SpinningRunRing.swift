import SwiftUI

struct SpinningRunRing: NSViewRepresentable {
  let color: Color
  let lineWidth: Double

  func makeNSView(context: Context) -> SpinningRunRingView {
    SpinningRunRingView()
  }

  func updateNSView(_ view: SpinningRunRingView, context: Context) {
    view.stroke(color: NSColor(color), lineWidth: lineWidth)
  }
}
