import MultishellCore
import SwiftUI

struct EmptyStateView: View {
  let hasProjects: Bool
  let theme: Theme
  let addProject: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Image(systemName: "arrow.trianglehead.branch")
        .font(.system(size: 40, weight: .light))
        .foregroundStyle(theme.textTertiary)

      Text(hasProjects ? t("empty.select-worktree") : t("empty.add-project"))
        .placeholderTitle(theme)

      Text(hasProjects ? t("empty.select-worktree-detail") : t("empty.add-project-detail"))
        .placeholderCaption(theme)

      if !hasProjects {
        Button(action: addProject) {
          Label(t("menu.add-project"), systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 22)
      }
    }
    .padding(48)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
