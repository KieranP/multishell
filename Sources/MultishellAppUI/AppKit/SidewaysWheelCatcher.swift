import SwiftUI

struct SidewaysWheelCatcher: NSViewRepresentable {
  let reference: ScrollerReference

  func makeNSView(context: Context) -> SidewaysWheelView { SidewaysWheelView() }

  func updateNSView(_ view: SidewaysWheelView, context: Context) { view.reference = reference }
}
