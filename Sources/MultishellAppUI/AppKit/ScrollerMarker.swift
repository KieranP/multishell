import SwiftUI

struct ScrollerMarker: NSViewRepresentable {
  let reference: ScrollerReference

  func makeNSView(context: Context) -> ScrollerMarkerView { ScrollerMarkerView() }

  func updateNSView(_ view: ScrollerMarkerView, context: Context) { view.reference = reference }
}
