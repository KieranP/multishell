import SwiftUI

struct MiddleClickCatcher: NSViewRepresentable {
  let action: () -> Void

  func makeNSView(context: Context) -> MiddleClickView { MiddleClickView() }

  func updateNSView(_ view: MiddleClickView, context: Context) { view.action = action }
}
