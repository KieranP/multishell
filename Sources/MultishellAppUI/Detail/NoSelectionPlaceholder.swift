import MultishellAppCore
import MultishellCore
import SwiftUI

struct NoSelectionPlaceholder: View {
  let hasProjects: Bool
  let theme: Theme
  let addProject: () -> Void

  var body: some View {
    DetailPlaceholder(
      title: NoSelectionText.title(hasProjects: hasProjects),
      caption: NoSelectionText.caption(hasProjects: hasProjects),
      theme: theme,
    ) {
      Image(systemName: "arrow.trianglehead.branch")
        .font(.system(size: 40, weight: .light))
        .foregroundStyle(theme.textTertiary)
        .accessibilityHidden(true)
    } footer: {
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
