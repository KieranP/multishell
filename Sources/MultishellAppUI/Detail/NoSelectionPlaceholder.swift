import MultishellAppCore
import MultishellCore
import SwiftUI

struct NoSelectionPlaceholder: View {
  let hasProjects: Bool
  let theme: Theme
  let metrics: UIMetrics
  let newProject: () -> Void

  var body: some View {
    DetailPlaceholder(
      title: NoSelectionText.title(hasProjects: hasProjects),
      caption: NoSelectionText.caption(hasProjects: hasProjects),
      theme: theme,
      metrics: metrics,
    ) {
      PlaceholderSymbol(symbol: "arrow.trianglehead.branch", theme: theme)
    } footer: {
      if !hasProjects {
        Button(action: newProject) {
          Label(t("menu.new-project"), systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, UIMetrics.placeholderFooterGap)
      }
    }
  }
}
