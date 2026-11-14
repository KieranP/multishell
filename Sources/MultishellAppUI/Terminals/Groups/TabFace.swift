import MultishellAppCore
import MultishellCore
import SwiftUI

/// What a tab in the strip shows, for any kind; `DraggableTab` wraps it in
/// both ends of a drag.
struct TabFace: View {
  let model: AppModel
  let group: TabGroup
  let tab: WorkspaceTab
  let isFocusedGroup: Bool
  let theme: Theme

  var body: some View {
    switch tab {
    case .allChanges(let allChanges):
      AllChangesTabFace(
        model: model,
        group: group,
        tab: allChanges,
        isFocusedGroup: isFocusedGroup,
        theme: theme,
      )

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
