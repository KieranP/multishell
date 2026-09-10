import MultishellAppCore
import MultishellCore
import SwiftUI

/// The two drop bands down the edges of one column's terminal area, drawn
/// while a dragged tab is over that area.
///
/// Dropping on one gives the tab a column of its own on that side. The space
/// between them takes the drop and does nothing with it: the strip above is
/// where a tab goes to join a column, and a second way to do that, live over
/// every terminal in the window, would be a lot of highlight for it. That
/// drop is not wasted though, since it is what ends a drag released over a
/// terminal.
struct TabGroupBands: View {
  let model: AppModel
  let group: TabGroup
  @Binding var drag: TabDragState

  var body: some View {
    GeometryReader { proxy in
      // A column too narrow to halve offers no band, so the drag springs
      // back rather than making two columns nobody can read.
      let fits = SplitMath.canHalve(
        Double(proxy.size.width), minimumPane: Double(SplitMetrics.minimumPane),
        divider: Double(SplitMetrics.dividerThickness))
      ZStack {
        // Under the bands, and the whole area: what tells them the pointer
        // has arrived, and, more to the point, that it has gone. A drop
        // between the bands joins this column.
        Color.clear
          .contentShape(.rect)
          .onDrop(
            of: [TabTransfer.contentType],
            delegate: TabAreaDropDelegate(
              groupID: group.id,
              drag: $drag,
              perform: { moving in model.moveTab(moving, toEndOf: group.id) })
          )
          .accessibilityLabel("Move tab to this group")
        if fits, drag.showsBands(of: group.id) {
          HStack(spacing: 0) {
            band(.before)
            Spacer(minLength: 0)
            band(.after)
          }
        }
      }
    }
  }

  private func band(_ placement: TerminalTab.Placement) -> some View {
    let target = TabDragState.Band(groupID: group.id, placement: placement)
    let isLit = drag.band == target
    return Color.accentColor
      .opacity(isLit ? 0.3 : 0.14)
      .frame(width: UIMetrics.dropBandWidth)
      .overlay(alignment: placement == .before ? .trailing : .leading) {
        // A line on the inside edge, where the new column's divider will
        // be, so the band reads as the column it is about to make.
        Color.accentColor.opacity(isLit ? 0.9 : 0.5).frame(width: 1)
      }
      .overlay {
        Image(systemName: "plus")
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(Color.accentColor.opacity(isLit ? 1 : 0.7))
      }
      .onDrop(
        of: [TabTransfer.contentType],
        delegate: TabBandDropDelegate(
          target: target,
          drag: $drag,
          perform: { moving in model.moveTab(moving, placement, toNewGroupOf: group.id) })
      )
      .accessibilityLabel(AccessibilityText.newTabGroupBand(placement))
  }
}
