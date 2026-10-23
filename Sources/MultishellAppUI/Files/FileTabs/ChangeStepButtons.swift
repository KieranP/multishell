import MultishellAppCore
import MultishellCore
import SwiftUI

/// The bar's two arrows in one segment well, as the Unified / Split switch
/// sits, up before down; an arrow with no change its way is greyed out.
struct ChangeStepButtons: View {
  let model: AppModel
  let tabID: FileTab.ID
  let palette: AreaPalette

  var body: some View {
    let steps = model.changeSteps(of: tabID)
    HStack(spacing: UIMetrics.segmentSpacing) {
      button(.previous, isEnabled: steps.allows(.previous))
      button(.next, isEnabled: steps.allows(.next))
    }
    .segmentWell(palette)
  }

  private func button(_ direction: CycleDirection, isEnabled: Bool) -> some View {
    let isNext = direction == .next
    let help = isNext ? t("file.next-change") : t("file.previous-change")
    return Button {
      model.stepToChange(direction, in: tabID)
    } label: {
      SegmentFace(isSelected: false, palette: palette, metrics: model.metrics) {
        Image(systemName: isNext ? "arrow.down" : "arrow.up")
          .foregroundStyle(isEnabled ? palette.textSecondary : palette.textTertiary)
      }
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .help(help)
    .accessibilityLabel(help)
  }
}
