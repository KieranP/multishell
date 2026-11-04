import MultishellAppCore
import MultishellCore
import SwiftUI

/// The selected worktree's panes, one `PaneRow` each, in tab order.
struct SelectedWorktreePanes: View {
  let model: AppModel
  let panes: [SidebarPane]
  let theme: Theme
  let metrics: UIMetrics

  /// The clock the rows' times read, held as the board holds its own.
  @State private var now = Date()

  // A stack rather than a bare ForEach, whose modifiers would start one clock per row.
  var body: some View {
    VStack(spacing: UIMetrics.sidebarRowSpacing) {
      ForEach(panes) { pane in
        PaneRow(
          pane: pane,
          now: now,
          theme: theme,
          metrics: metrics,
          select: { [model] in model.show(pane: pane.id) },
        )
        .equatable()
      }
    }
    .ticking($now, every: .elapsedTick)
  }
}
