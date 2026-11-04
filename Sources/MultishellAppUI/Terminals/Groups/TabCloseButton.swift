import MultishellAppCore
import MultishellCore
import SwiftUI

/// The X on a tab of either kind, its room kept while it is hidden. Closes its
/// own tab, like the middle click; `closeActiveTab` asks which window is key.
struct TabCloseButton: View {
  let metrics: UIMetrics
  /// The tab's own colours, which the X's glyph is drawn in.
  let palette: AreaPalette
  /// The strip's, whose fill lights the X, as a terminal tab's section has none.
  let stripPalette: AreaPalette
  let isVisible: Bool
  /// Closes the tab; a face whose close can raise a dialog unlights itself in it.
  let close: () -> Void

  @State private var isHovered = false

  private var side: Double { metrics.tabCloseButtonSide }

  var body: some View {
    // Built only while drawn, so a strip of tabs carries one tooltip and
    // tracking area for each X on screen rather than for every tab.
    Group {
      if isVisible {
        button
      } else {
        Color.clear.frame(width: side, height: side)
      }
    }
    // A hidden X hears no exit, so it would come back lit.
    .onChange(of: isVisible) { _, isVisible in
      if !isVisible { isHovered = false }
    }
  }

  private var button: some View {
    // Unlit by its click, as the close dialog it can raise hides the pointer's exit.
    PlainGlyphButton(help: t("tab.close")) {
      isHovered = false
      close()
    } glyph: {
      Image(systemName: "xmark")
        .font(metrics.font(size: metrics.small, weight: .semibold))
        .frame(width: side, height: side)
        .glyphHover(
          isHovered,
          palette: stripPalette,
          resting: palette.textSecondary,
          lit: palette.text,
        )
        .accessibilityHidden(true)
    }
    .tracksHover($isHovered)
  }
}
