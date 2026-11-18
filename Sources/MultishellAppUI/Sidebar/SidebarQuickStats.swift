import MultishellAppCore
import MultishellCore
import SwiftUI

/// The quick stats under the footer while debug tools are on. The model is read
/// in this body, so each second's sample redraws three cells, not the sidebar.
struct SidebarQuickStats: View {
  let model: AppModel
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    let stats = model.debugQuickStats
    HStack(spacing: 6) {
      cell(
        title: t("debug.quick-cpu"),
        value: stats.totalCPUText,
        trend: stats.cpuTrend,
        trendColor: theme.debugAppSeriesColor,
      )
      cell(
        title: t("debug.quick-memory"),
        value: stats.totalMemoryText,
        trend: stats.memoryTrend,
        trendColor: theme.debugChildrenSeriesColor,
      )
      cell(
        title: t("debug.quick-disk"),
        value: stats.diskText,
        trend: stats.diskTrend,
        trendColor: theme.debugTerminalsSeriesColor,
      )
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 5)
    .rowSelection(theme.projectsPanel, isSelected: model.showsDebugInfo)
    .contentShape(.rect)
    .onTapGesture { model.showDebugInfo() }
    .padding(.horizontal, 6)
    .padding(.bottom, 6)
    .help(t("debug.quick-help"))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.debugQuickStats(stats))
    .selectableButtonTraits(isSelected: model.showsDebugInfo)
  }

  private func cell(
    title: String,
    value: String,
    trend: [Double],
    trendColor: Color,
  ) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(title)
        .font(metrics.font(size: metrics.small, weight: .semibold))
        .foregroundStyle(theme.projectsPanel.textTertiary)
      Text(value)
        .font(metrics.font(size: metrics.badge, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(theme.projectsPanel.text)
        .lineLimit(1)
      QuickStatsSparkline(values: trend)
        .stroke(trendColor, lineWidth: 1.2)
        .frame(height: 14)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
