import MultishellAppCore
import MultishellCore
import SwiftUI

/// The field the tree is filtered by, folded away until asked for. It takes
/// the keyboard as it appears, so the magnifier is one click.
struct SidebarFilterField: View {
  @Binding var filter: String
  let theme: Theme
  let metrics: UIMetrics
  let close: () -> Void

  @FocusState private var focused: Bool

  var body: some View {
    HStack(spacing: 6) {
      TextField(t("sidebar.filter"), text: $filter)
        .textFieldStyle(.plain)
        .font(.system(size: metrics.secondary))
        .foregroundStyle(theme.textPrimary)
        .focused($focused)
        // A turn later: focus does not take on a field the hierarchy has not
        // installed yet.
        .task { focused = true }
        .onExitCommand(perform: close)
      if SidebarFilter(filter).isActive {
        Button {
          filter = ""
          focused = true
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: metrics.icon))
            .foregroundStyle(theme.textTertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t("sidebar.clear-filter"))
      }
    }
    .padding(.horizontal, 8)
    .frame(height: (metrics.body * 1.85).rounded())
    .background(theme.rowHover, in: RoundedRectangle(cornerRadius: 6))
    .padding(.horizontal, 8)
  }
}
