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
    PanelHeader(
      title: t("label.agents"), summary: board.summary, summaryColor: theme.textTertiary,
      theme: theme, metrics: metrics
    ) {
      allTerminalsToggle
    }
  }

  /// The board's one control, deciding membership and nothing else: a shell
  /// it lets in lands where its state says, as an agent does.
  private var allTerminalsToggle: some View {
    Toggle(t("board.show-all-terminals"), isOn: model.showsAllTerminalsBinding)
      .toggleStyle(.switch)
      .controlSize(.mini)
      .font(.system(size: metrics.caption))
      .foregroundStyle(theme.textSecondary)
      .help(t("board.show-all-terminals-info"))
  }
}
