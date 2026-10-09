import MultishellAppCore
import MultishellCore
import SwiftUI

/// The panel's own header, as tall as the title-bar band: its name, the
/// range's stalls, the range picker and Pause.
struct DebugInfoHeader: View {
  let model: AppModel
  let timeline: DebugTimeline
  @Binding var range: DebugRange
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    PanelHeader(
      title: t("debug.title"),
      summary: timeline.stallSummary,
      summaryColor: timeline.hasStalls ? theme.failureColor : theme.textTertiary,
      theme: theme,
      metrics: metrics,
    ) {
      Picker(t("debug.range"), selection: $range) {
        ForEach(DebugRange.allCases, id: \.self) { range in
          Text(range.title).tag(range)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .controlSize(.small)
      .fixedSize()
      Toggle(t("debug.pause"), isOn: model.debugPausedBinding)
        .toggleStyle(.button)
        .controlSize(.small)
    }
  }
}
