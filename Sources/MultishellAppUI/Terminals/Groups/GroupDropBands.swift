import MultishellAppCore
import MultishellCore
import SwiftUI

/// The two drop bands down a group's terminal area, drawn while a tab is
/// over it: dropping on one gives the tab a group of its own that side.
struct GroupDropBands: View {
  let model: AppModel
  let group: TabGroup
  @Binding var drag: TabDragState

  var body: some View {
    GeometryReader { proxy in
      // A group too narrow to halve offers no band, rather than make two
      // groups nobody can read; the release reaches the area beneath.
      let fits = SplitMath.canHalve(
        Double(proxy.size.width), minimumPane: UIMetrics.minimumPaneLength,
        divider: UIMetrics.splitDividerThickness)
      ZStack {
        // Under the bands and the whole area: what tells them the pointer
        // has arrived and, more to the point, that it has gone.
        Color.clear
          .contentShape(.rect)
          .onDrop(
            of: [TabTransfer.contentType],
            delegate: GroupAreaDropDelegate(
              groupID: group.id,
              drag: $drag,
              drop: { model.dropDraggedTab(on: .area(group.id)) })
          )
          .accessibilityLabel(t("tab.move-to-this-group"))
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
        // A line on the inside edge, where the new group's divider will
        // be, so the band reads as the group it is about to make.
        Color.accentColor.opacity(isLit ? 0.9 : 0.5).frame(width: 1)
      }
      .overlay {
        Image(systemName: "plus")
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(Color.accentColor.opacity(isLit ? 1 : 0.7))
      }
      .onDrop(
        of: [TabTransfer.contentType],
        delegate: GroupBandDropDelegate(
          band: target,
          drag: $drag,
          drop: { model.dropDraggedTab(on: .band(target)) })
      )
      .accessibilityLabel(AccessibilityText.newTabGroupBand(placement))
  }
}
