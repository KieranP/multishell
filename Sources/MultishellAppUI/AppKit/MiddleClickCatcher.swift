import SwiftUI

struct MiddleClickCatcher: NSViewRepresentable {
  let onMiddleClick: () -> Void

  func makeNSView(context: Context) -> MiddleClickView { MiddleClickView() }

  func updateNSView(_ view: MiddleClickView, context: Context) {
    view.onMiddleClick = onMiddleClick
  }
}
