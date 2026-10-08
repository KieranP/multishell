import MultishellAppCore
import MultishellCore
import SwiftUI

/// The field the tree is filtered by, hidden until asked for. It takes
/// the keyboard as it appears, so the magnifier is one click.
struct SidebarFilterField: View {
  @Binding var text: String
  let isFiltering: Bool
  let theme: Theme
  let metrics: UIMetrics
  let close: () -> Void

  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 6) {
      TextField(t("sidebar.filter"), text: $text)
        .textFieldStyle(.plain)
        .font(.system(size: metrics.secondary))
        .foregroundStyle(theme.textPrimary)
        .focused($isFocused)
        // A turn later: focus does not take on a field the hierarchy has not
        // installed yet.
        .task { isFocused = true }
        .onExitCommand(perform: close)
      if isFiltering {
        PlainGlyphButton(help: t("sidebar.clear-filter")) {
          text = ""
          isFocused = true
        } glyph: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: metrics.glyph))
            .foregroundStyle(theme.textTertiary)
        }
      }
    }
    .padding(.horizontal, 8)
    .frame(height: metrics.sidebarFilterHeight)
    .background(theme.faintFill, in: RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius))
    .padding(.horizontal, 8)
  }
}
