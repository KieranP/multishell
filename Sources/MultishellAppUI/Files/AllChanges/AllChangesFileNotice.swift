import MultishellAppCore
import MultishellCore
import SwiftUI

/// Why a file of the All changes tab shows no rows, with its own tab offered
/// where that shows what this cannot.
struct AllChangesFileNotice: View {
  let model: AppModel
  let worktreeID: Worktree.ID
  let path: String
  let notice: AllChangesNotice
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    HStack(spacing: 12) {
      Text(AllChangesText.notice(notice))
        .foregroundStyle(theme.fileTab.textSecondary)
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 0)
      if AllChangesText.offersFileTab(for: notice) {
        Button(t("all-changes.open-file")) {
          Task { await model.openFileAsTab(path, in: worktreeID) }
        }
        .buttonStyle(ThemedButtonStyle(fill: theme.fileTab.fill, text: theme.fileTab.text))
      }
    }
    .font(metrics.font(size: metrics.secondary))
    .padding(.horizontal, 14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(theme.fileTab.background)
  }
}
