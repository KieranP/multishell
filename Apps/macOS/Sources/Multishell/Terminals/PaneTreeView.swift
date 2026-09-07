import MultishellAppCore
import MultishellCore
import SwiftUI

/// Renders a tab's `PaneNode`. A leaf is a surface; a split is a
/// `WeightedSplit` that lays children out by the model's weights and writes
/// divider drags back, so proportions are exact and persist.
struct PaneTreeView: View {
  let model: AppModel
  let tabID: TerminalTab.ID
  let node: PaneNode
  var path: [Int] = []
  let focusedSessionID: TerminalSession.ID
  let isSplit: Bool
  let theme: Theme

  var body: some View {
    switch node {
    case .terminal(let id):
      SurfaceView(
        model: model,
        sessionID: id,
        isFocused: id == focusedSessionID,
        isLive: model.liveSessions.contains(id)
      )
      .overlay {
        if isSplit, id == focusedSessionID {
          Rectangle().strokeBorder(theme.selectionRGB.color, lineWidth: 1)
        }
      }

    case .split(let axis, let children, let weights):
      WeightedSplit(
        axis: axis,
        weights: weights,
        divider: theme.hairline,
        background: theme.chromeColor,
        onWeightsChange: { model.setSplitWeights($0, at: path, ofTab: tabID) },
        content: {
          ForEach(children.indices, id: \.self) { index in
            PaneTreeView(
              model: model,
              tabID: tabID,
              node: children[index],
              path: path + [index],
              focusedSessionID: focusedSessionID,
              isSplit: isSplit,
              theme: theme
            )
          }
        }
      )
    }
  }
}
