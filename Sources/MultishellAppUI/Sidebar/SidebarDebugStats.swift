import MultishellAppCore
import MultishellCore
import SwiftUI

/// The quick stats under the footer while debug tools are on. The model is read
/// in this body, so each second's sample redraws three cells, not the sidebar.
struct SidebarDebugStats: View {
  let model: AppModel
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    let stats = model.debugQuickStats
    HStack(spacing: 6) {
      cell(
        title: t("debug.quick-fps"),
        value: stats.framesPerSecondText,
        valueColor: theme.color(for: stats.smoothness),
        trend: stats.frameRateTrend, trendColor: theme.debugAppSeriesColor)
      cell(
        title: t("debug.quick-cpu"),
        value: stats.totalCPUText,
        valueColor: theme.textPrimary,
        trend: stats.cpuTrend, trendColor: theme.debugAppSeriesColor)
      cell(
        title: t("debug.quick-memory"),
        value: stats.totalMemoryText,
        valueColor: theme.textPrimary,
        trend: stats.memoryTrend, trendColor: theme.debugChildrenSeriesColor)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 5)
    .rowSelection(isSelected: model.showsDebugInfo)
    .contentShape(.rect)
    .onTapGesture { model.showDebugInfo() }
    .padding(.horizontal, 6)
    .padding(.bottom, 6)
    .help(t("debug.quick-help"))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.debugQuickStats(stats))
    .accessibilityAddTraits(model.showsDebugInfo ? [.isButton, .isSelected] : .isButton)
  }

  private func cell(
    title: String, value: String, valueColor: Color, trend: [Double], trendColor: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(title)
        .font(.system(size: metrics.small, weight: .semibold))
        .foregroundStyle(theme.textTertiary)
      Text(value)
        .font(.system(size: metrics.badge, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(valueColor)
        .lineLimit(1)
      DebugSparkline(values: trend)
        .stroke(trendColor, lineWidth: 1.2)
        .frame(height: 14)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
