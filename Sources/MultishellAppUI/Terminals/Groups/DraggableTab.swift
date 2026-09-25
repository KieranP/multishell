import MultishellAppCore
import MultishellCore
import SwiftUI

/// One tab in a group's strip: its `TabFace` and both ends of dragging it.
/// `TabStrip` places and sizes them.
struct DraggableTab: View {
  let model: AppModel
  /// The group this tab sits in, which its own moves are measured against.
  let group: TabGroup
  let tab: TerminalTab
  /// Whether this group takes the keystrokes. Only its active tab reads at
  /// full strength; another group's still fills, being on screen.
  let isFocusedGroup: Bool
  /// Whether the group has another tab, so this one leaving it would be a
  /// move rather than the same layout under a new id.
  let canLeaveGroup: Bool
  /// Whether the tab in the air is this group's, so it moves as the pointer
  /// goes. One from another group has not moved, and the line says where.
  let isShuffling: Bool
  /// Exactly this wide, so the drop can tell which half of it the pointer
  /// is in without measuring; see `TabStripLayout`.
  let width: Double
  let theme: Theme
  @Binding var drag: TabDragState

  private var isInTheAir: Bool {
    drag.tabID == tab.id && drag.isEngaged
  }

  var body: some View {
    TabFace(
      model: model, group: group, tab: tab, isFocusedGroup: isFocusedGroup,
      canLeaveGroup: canLeaveGroup, theme: theme
    )
    // The tab in the air, read from the drop targets rather than the drag
    // beginning, so one let go unseen cannot mark a tab for good.
    .opacity(isInTheAir ? (isShuffling ? 0.55 : 0.3) : 1)
    .frame(width: width)
    .clipped()
    .overlay(alignment: drag.insertion?.placement == .after ? .trailing : .leading) {
      insertionLine
    }
    .inAppDragSource(
      begin: {
        model.beginTabDrag(tab.id)
        return TabTransfer.itemProvider()
      },
      preview: {
        // A drag with no image of its own: AppKit holds its preview card
        // for most of a second after the drop, so the tab is the preview.
        Color.clear.frame(width: 1, height: 1)
      },
      ended: { model.endAbandonedTabDrag(tab.id) },
      sourceLeft: { model.tabDragSourceLeft(tab.id, isPressed: $0) }
    )
    .onDrop(
      of: [TabTransfer.contentType],
      delegate: TabDropDelegate(
        tabID: tab.id,
        width: width,
        drag: $drag,
        drop: { placement in model.dropDraggedTab(on: .tab(tab.id, placement)) },
        shuffle: { moving, placement in
          withAnimation(.easeOut(duration: 0.14)) {
            model.shuffleTab(moving, placement, past: tab.id)
          }
        }
      ))
  }

  /// Where the dragged tab will land, on the tab the pointer is over. The
  /// sidebar draws the same line lying down.
  @ViewBuilder
  private var insertionLine: some View {
    if drag.isDragging, !isShuffling, let insertion = drag.insertion, insertion.tabID == tab.id {
      InsertionLine(axis: .vertical, isAfter: insertion.placement != .before)
    }
  }
}

/// Everything but the model, which is one object, and the binding, compared
/// by its value; the body's reads of the model are observed on their own.
extension DraggableTab: @MainActor Equatable {
  static func == (a: DraggableTab, b: DraggableTab) -> Bool {
    a.model === b.model && a.group == b.group && a.tab == b.tab
      && a.isFocusedGroup == b.isFocusedGroup
      && a.canLeaveGroup == b.canLeaveGroup && a.isShuffling == b.isShuffling
      && a.width == b.width && a.theme == b.theme && a.drag == b.drag
  }
}
