import MultishellAppCore
import MultishellCore
import SwiftUI

/// The panel's own header, as tall as the title-bar band: its name, the
/// range's stalls, the range picker and Pause.
struct DebugInfoHeader: View {
  let model: AppModel
  let stalledSecondCount: Int
  @Binding var range: DebugRange
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack(spacing: 8) {
      Text(t("debug.title"))
        .font(.system(size: metrics.body, weight: .semibold))
        .foregroundStyle(theme.textPrimary)
      Text(
        t(
          "debug.stalled-seconds", t("count.stalled-seconds", stalledSecondCount),
          DebugValueText.duration(Smoothness.stallThreshold))
      )
      .font(.system(size: metrics.caption))
      .foregroundStyle(stalledSecondCount > 0 ? theme.failureColor : theme.textTertiary)
      .lineLimit(1)
      Spacer(minLength: 8)
      Picker(t("debug.range"), selection: $range) {
        ForEach(DebugRange.allCases, id: \.self) { range in
          Text(range.title).tag(range)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .controlSize(.small)
      .fixedSize()
      Toggle(t("debug.pause"), isOn: model.debugPausedSetting)
        .toggleStyle(.button)
        .controlSize(.small)
    }
    .windowHeader(fill: theme.chromeColor)
  }
}
