import MultishellCore
import SwiftUI

struct NoSelectionPlaceholder: View {
  let hasProjects: Bool
  let theme: Theme
  let addProject: () -> Void

  var body: some View {
    DetailPlaceholder(
      title: hasProjects ? t("empty.select-worktree") : t("empty.add-project"),
      caption: hasProjects ? t("empty.select-worktree-detail") : t("empty.add-project-detail"),
      theme: theme
    ) {
      Image(systemName: "arrow.trianglehead.branch")
        .font(.system(size: 40, weight: .light))
        .foregroundStyle(theme.textTertiary)
    } extra: {
      if !hasProjects {
        Button(action: addProject) {
          Label(t("menu.add-project"), systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 22)
      }
    }
  }
}
