import MultishellAppCore
import MultishellCore
import SwiftUI

/// The panel's own header, as tall as the title-bar band: its name, the
/// range's stalls, the range switch and Pause.
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
      summaryColor: timeline.hasStalls ? theme.debugStallColor : theme.header.textTertiary,
      theme: theme,
      metrics: metrics,
    ) {
      SegmentedSwitch(
        label: t("debug.range"),
        options: DebugRange.allCases.map { ($0.title, $0) },
        selection: $range,
        theme: theme,
        section: .header,
        metrics: metrics,
      )
      Toggle(t("debug.pause"), isOn: model.debugPausedBinding)
        .toggleStyle(SegmentToggleStyle(theme: theme, section: .header, metrics: metrics))
    }
  }
}
