import MultishellAppCore
import MultishellCore
import SwiftUI

/// The top file's header held over the rows once its own scrolled past; a view of
/// its own, as each frame of a push then redraws it alone, not the list.
struct AllChangesStickyHeader: View {
  /// The top of a file's box, as the mockup keeps it over the rows.
  private static let shape = UnevenRoundedRectangle(
    topLeadingRadius: UIMetrics.allChangesBoxCornerRadius,
    topTrailingRadius: UIMetrics.allChangesBoxCornerRadius,
  )

  let model: AppModel
  let tab: AllChangesTab
  let document: AllChangesDocument
  /// By path, counted by the tab's body rather than on every frame of a push.
  let pendingComments: [String: Int]
  let theme: Theme

  var body: some View {
    if let top = model.allChangesTopFile(of: tab.id), top.isHeaderScrolledPast,
      let index = document.section(at: top.path)
    {
      AllChangesFileHeader(
        model: model,
        tabID: tab.id,
        worktreeID: tab.worktreeID,
        section: document.sections[index],
        pendingComments: pendingComments[top.path] ?? 0,
        theme: theme,
      )
      .clipShape(Self.shape)
      .overlay { Self.shape.stroke(theme.fileTab.border, lineWidth: 1) }
      .padding(.leading, UIMetrics.allChangesBoxMargin)
      .padding(.trailing, UIMetrics.allChangesScrollerMargin)
      .offset(y: -top.pushedUp)
      .allowsHitTesting(top.takesClicks)
    }
  }
}
