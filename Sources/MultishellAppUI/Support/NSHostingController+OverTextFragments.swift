import AppKit
import SwiftUI

extension NSHostingController where Content == AnyView {
  /// An empty host in `parent`, sized by whoever places it.
  static func overTextFragments(in parent: NSView?) -> NSHostingController<AnyView> {
    let host = NSHostingController(rootView: AnyView(EmptyView()))
    host.sizingOptions = []
    host.view.wantsLayer = true
    // TextKit 2 adds its fragments' views as it lays out; the host stays over them.
    host.view.layer?.zPosition = 1
    parent?.addSubview(host.view)
    return host
  }
}
