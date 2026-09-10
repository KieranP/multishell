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
      // a surface given focus reports it back, which focuses its column, so
      // two panes asking would leave the columns trading the focus between
      // renders.
      let isActive = isFocusedColumn && id == focusedSessionID
      SurfaceView(
        model: model,
        sessionID: id,
        isFocused: isActive,
        isLive: model.liveSessions.contains(id)
      )
      .overlay { fade(isActive: isActive) }
      .overlay { ring(isActive: isActive) }

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
  private func ring(isActive: Bool) -> some View {
    if showsFocusRing, isActive, let colour = theme.focusRingRGB {
      Rectangle().strokeBorder(colour.color, lineWidth: 1)
    }
  }

  /// Every pane but the focused one fades towards the theme's own
  /// background by `inactivePaneOpacity`.
  ///
  /// A scrim rather than `.opacity` on the surface: the panes are
  /// `NSView`s, one of them Metal-backed, and view opacity is not something
  /// both engines honour the same way. Hit testing is off, so a click still
  /// reaches the terminal underneath and focuses it, which is what undims
  /// it.
  @ViewBuilder
  private func fade(isActive: Bool) -> some View {
    let opacity = theme.inactivePaneOpacity
    if !isActive, opacity < 1 {
      theme.backgroundColor
        .opacity(1 - opacity)
        .allowsHitTesting(false)
    }
  }
}
