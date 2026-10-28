import MultishellAppCore
import MultishellCore
import SwiftUI

/// A services' page's collapsible section: a chevron and its title in caps.
struct PanelSectionHeader: View {
  let title: String
  @Binding var isExpanded: Bool
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    Button {
      isExpanded.toggle()
    } label: {
      HStack(spacing: 6) {
        DisclosureChevron(isExpanded: isExpanded, metrics: metrics)
        Text(title.uppercased())
          .font(metrics.font(size: metrics.small, weight: .semibold))
          .tracking(0.4)
        Spacer(minLength: 0)
      }
      .foregroundStyle(theme.filesPanel.textTertiary)
      .padding(.horizontal, UIMetrics.servicePageSideInset)
      .frame(height: metrics.paneRowHeight)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityValue(AccessibilityText.disclosure(isExpanded: isExpanded))
  }
}
