import MultishellAppCore
import MultishellCore
import SwiftUI

/// Renders a tab's `PaneNode`: a leaf is a surface, a split a `WeightedSplit`
/// laying children out by the model's weights and writing drags back.
struct PaneTreeView: View {
  let model: AppModel
  let tabID: TerminalTab.ID
  let node: PaneNode
  var path: [Int] = []
  let focusedSessionID: TerminalSession.ID
  /// Whether this tree is in the column the keystrokes go to. One pane in
  /// the window is the focused one, and it is in the focused column.
  let isFocusedColumn: Bool
  /// Whether the focused pane wears the theme's ring: only where there is
  /// something to tell it apart from, a split or a second column.
  let showsFocusRing: Bool
  let theme: Theme

  var body: some View {
    switch node {
    case .terminal(let id):
      // One pane in the window asks for the keyboard, not one per column:
      // a surface reports focus back, so two would trade it between renders.
      let isFocusedPane = isFocusedColumn && id == focusedSessionID
      SurfaceView(
        model: model,
        sessionID: id,
        isFocused: isFocusedPane,
        isLive: model.liveSessions.contains(id)
      )
      .overlay { fade(isFocusedPane: isFocusedPane) }
      .overlay { ring(isFocusedPane: isFocusedPane) }
      .overlay(alignment: .topTrailing) {
        if model.findingSessionIDs.contains(id) {
          FindBar(model: model, sessionID: id, theme: theme)
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
              isFocusedColumn: isFocusedColumn,
              showsFocusRing: showsFocusRing,
              theme: theme
            )
          }
        }
      )
    }
  }

  /// The theme's `focusRing`, which a theme may set to any colour or leave
  /// empty for no ring at all.
  @ViewBuilder
  private func ring(isFocusedPane: Bool) -> some View {
    if showsFocusRing, isFocusedPane, let colour = theme.focusRingRGB {
      Rectangle().strokeBorder(colour.color, lineWidth: 1)
    }
  }

  /// Every pane but the focused one fades towards the theme's background. A
  /// scrim, not `.opacity`, which a Metal-backed surface may ignore.
  @ViewBuilder
  private func fade(isFocusedPane: Bool) -> some View {
    let opacity = theme.inactivePaneOpacity
    if !isFocusedPane, opacity < 1 {
      theme.backgroundColor
        .opacity(1 - opacity)
        .allowsHitTesting(false)
    }
  }
}
