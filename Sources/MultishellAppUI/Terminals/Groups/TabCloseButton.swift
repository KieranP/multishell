import MultishellAppCore
import MultishellCore
import SwiftUI

/// The X on the active tab of either kind. Names its own tab, like the middle
/// click; `closeActiveTab` is for the keystroke, which asks which window is key.
struct TabCloseButton: View {
  let model: AppModel
  let tabID: WorkspaceTab.ID
  let palette: AreaPalette

  var body: some View {
    PlainGlyphButton(help: t("tab.close")) {
      model.closeTab(tabID)
    } glyph: {
      Image(systemName: "xmark")
        .font(model.metrics.font(size: model.metrics.small, weight: .semibold))
        .frame(width: model.metrics.tabCloseButtonSide, height: model.metrics.tabCloseButtonSide)
        .accessibilityHidden(true)
    }
    .foregroundStyle(palette.textSecondary)
  }
}
