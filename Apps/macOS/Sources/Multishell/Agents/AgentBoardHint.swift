import MultishellAppCore
import MultishellCore
import SwiftUI

/// One line under the columns while there is nothing on them, saying what
/// would put something there. The wording is the board's; see
/// `AgentBoard.emptyHint`.
struct AgentBoardHint: View {
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    Text(AgentBoard.emptyHint)
      .font(.system(size: metrics.caption))
      .foregroundStyle(theme.textTertiary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .overlay(alignment: .top) { theme.hairline.frame(height: 0.5) }
  }
}
