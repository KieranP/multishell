import MultishellAppCore
import MultishellCore
import SwiftUI

/// The scopes under the field, the one in force filled; Tab steps through them.
struct QuickSwitcherScopeBar: View {
  let scope: QuickSwitcherScope
  let palette: AreaPalette
  let metrics: UIMetrics
  let setScope: (QuickSwitcherScope) -> Void

  var body: some View {
    HStack(spacing: UIMetrics.segmentSpacing * 2) {
      ForEach(QuickSwitcherScope.allCases) { candidate in
        let isInForce = candidate == scope
        Button {
          setScope(candidate)
        } label: {
          Text(candidate.title)
            .font(metrics.font(size: metrics.caption, weight: isInForce ? .semibold : .regular))
            .foregroundStyle(isInForce ? palette.text : palette.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
              isInForce ? palette.color(.selectionBackground) : .clear,
              in: RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius),
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .selectableButtonTraits(isSelected: isInForce)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
  }
}
