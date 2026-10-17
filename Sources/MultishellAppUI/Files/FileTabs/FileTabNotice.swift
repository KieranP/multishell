import MultishellAppCore
import MultishellCore
import SwiftUI

/// What a file tab shows in place of rows: a binary file, one too large, one
/// that is nowhere, each with the editor a click away.
struct FileTabNotice: View {
  let model: AppModel
  let tab: FileTab
  let content: FileTabContent
  let theme: Theme

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(FileTabNoticeText.message(for: content) ?? "")
        .foregroundStyle(theme.fileTab.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
      if FileTabNoticeText.offersEditor(for: content) {
        Button(t("action.open-in-editor")) {
          model.openInEditor(path: tab.path, in: tab.worktreeID)
        }
      }
    }
    .font(model.metrics.font(size: model.metrics.secondary))
    .padding(.horizontal, 24)
    .padding(.vertical, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}
