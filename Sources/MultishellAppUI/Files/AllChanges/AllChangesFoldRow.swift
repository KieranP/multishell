import MultishellAppCore
import MultishellCore
import SwiftUI

/// Unchanged lines left out of the All changes tab, a click showing them.
struct AllChangesFoldRow: View {
  /// The band under the label, the label's blue held well back.
  private static let bandOpacity = 0.1

  let model: AppModel
  let tabID: AllChangesTab.ID
  let path: String
  let lines: ClosedRange<Int>
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    let palette = theme.fileTab
    // The waiting blue Review's To send chips and the gutter's + wear.
    let blue = theme.color(.waiting, in: .states)
    Button {
      model.openAllChangesFold(lines, of: path, in: tabID)
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "chevron.up.chevron.down")
          .font(metrics.font(size: metrics.small))
          .foregroundStyle(blue)
          .frame(width: UIMetrics.allChangesFoldGlyphColumn)
          .accessibilityHidden(true)
        Text(AllChangesText.foldTitle(lines)).foregroundStyle(blue)
        Text(AllChangesText.foldLines(lines)).foregroundStyle(palette.textTertiary)
        Spacer(minLength: 0)
      }
      .font(metrics.font(size: metrics.secondary))
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .background(blue.opacity(Self.bandOpacity))
      .background(palette.background)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}
