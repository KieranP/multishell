import MultishellAppCore
import MultishellCore
import SwiftUI

/// Why a file of the All changes tab shows no rows, with its own tab or the
/// editor a click away; `AllChangesNotice.action` says which.
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
      switch notice.action {
      case .openFile:
        button(t("all-changes.open-file")) {
          Task { await model.openFileAsTab(path, in: worktreeID) }
        }

      case .openInEditor:
        button(t("action.open-in-editor")) { model.openInEditor(path: path, in: worktreeID) }

      case nil:
        EmptyView()
      }
    }
    .font(metrics.font(size: metrics.secondary))
    .padding(.horizontal, 14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(theme.fileTab.background)
  }

  private func button(_ title: String, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
      .buttonStyle(ThemedButtonStyle(fill: theme.fileTab.fill, text: theme.fileTab.text))
  }
}
