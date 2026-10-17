import MultishellAppCore
import MultishellCore
import SwiftUI

/// Places one session's surface in the SwiftUI tree. The surface view
/// outlives any `PaneSurface`, so the process and scrollback survive.
struct PaneSurface: NSViewRepresentable {
  let model: AppModel
  let sessionID: TerminalSession.ID
  let isFocused: Bool
  /// Read so that a session opened after this view first drew, which
  /// changes nothing in the workspace, still triggers `updateNSView`.
  let isLive: Bool
  /// The border a pane draws while files are dragged over it.
  let dropHighlightColor: RGB

  func makeNSView(context: Context) -> SurfaceFrame { SurfaceFrame() }

  func updateNSView(_ frame: SurfaceFrame, context: Context) {
    frame.dropHighlightColor = dropHighlightColor.nsColor
    frame.acceptsDrop = { [model] in model.acceptsFileDrop(into: sessionID) }
    frame.receiveDrop = { [model] urls, focus in
      model.dropFiles(urls, into: sessionID, takingFocus: focus)
    }
    frame.show(model.surface(for: sessionID), focused: isFocused) { [model] in
      model.focusSurface(sessionID)
    }
  }
}
