import MultishellAppCore
import MultishellCore
import SwiftUI

/// The board's own header, as tall as the title-bar band the detail header
/// fills; see `UIMetrics.headerHeight`.
struct AgentBoardHeader: View {
  let model: AppModel
  let board: AgentBoard
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack(spacing: 8) {
      Text("Agents")
        .font(.system(size: metrics.body, weight: .semibold))
        .foregroundStyle(theme.textPrimary)
      Text(board.summary)
        .font(.system(size: metrics.caption))
        .foregroundStyle(theme.textTertiary)
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 8)
      allTerminalsToggle
    }
    .padding(.horizontal, 14)
    .frame(height: UIMetrics.headerHeight)
    .background(theme.chromeColor)
    .titleBarDoubleClick()
  }

  /// The board's one control. It decides membership and nothing else: a
  /// shell it lets in lands in the column its state says, exactly as an
  /// agent does.
  private var allTerminalsToggle: some View {
    Toggle(
      "Show all terminals",
      isOn: Binding(
        get: { model.showsAllTerminals }, set: { model.setShowsAllTerminals($0) })
    )
    .toggleStyle(.switch)
    .controlSize(.mini)
    .font(.system(size: metrics.caption))
    .foregroundStyle(theme.textSecondary)
    .help("Show terminals with no agent at the prompt")
  }
}
