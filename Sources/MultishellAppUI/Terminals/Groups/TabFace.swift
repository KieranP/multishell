import MultishellAppCore
import MultishellCore
import SwiftUI

/// What a tab in the strip shows, for either kind; `DraggableTab` wraps it in
/// both ends of a drag.
struct TabFace: View {
  let model: AppModel
  let group: TabGroup
  let tab: WorkspaceTab
  let isFocusedGroup: Bool
  let theme: Theme

  var body: some View {
    switch tab {
    case .file(let file):
      FileTabFace(
        model: model,
        group: group,
        tab: file,
        isFocusedGroup: isFocusedGroup,
        theme: theme,
      )

    case .terminal(let terminal):
      TerminalTabFace(
        model: model,
        group: group,
        tab: terminal,
        isFocusedGroup: isFocusedGroup,
        theme: theme,
      )
    }
  }
}
