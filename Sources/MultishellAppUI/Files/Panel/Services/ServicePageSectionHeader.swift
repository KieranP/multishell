import MultishellAppCore
import MultishellCore
import SwiftUI

/// A services' page's collapsible section: a chevron and its title in caps, and
/// whatever sits at its trailing edge, such as Latest run's checkbox.
struct ServicePageSectionHeader<Trailing: View>: View {
  let title: String
  @Binding var isExpanded: Bool
  let theme: Theme
  let metrics: UIMetrics
  /// After the title in its own case, such as "1 to send" over a collapsed list.
  var detail: String?
  @ViewBuilder let trailing: () -> Trailing

  var body: some View {
    Button {
      isExpanded.toggle()
    } label: {
      HStack(spacing: 6) {
        DisclosureChevron(
          isExpanded: isExpanded,
          size: metrics.servicePageMarkSize,
          weight: .semibold,
          metrics: metrics,
        )
        Text(title.uppercased())
          .font(metrics.font(size: metrics.small, weight: .semibold))
          .tracking(UIMetrics.filesPanelHeadingTracking)
        if let detail {
          Text(detail).font(metrics.font(size: metrics.caption))
        }
        Spacer(minLength: 0)
      }
      .foregroundStyle(theme.filesPanel.textTertiary)
      .padding(.horizontal, UIMetrics.servicePageSideInset)
      .frame(height: metrics.paneRowHeight)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel([title, detail].compactMap(\.self).joined(separator: ", "))
    .accessibilityValue(AccessibilityText.disclosure(isExpanded: isExpanded))
    // Over the button rather than beside it, so the whole row still toggles.
    .overlay(alignment: .trailing) {
      trailing().padding(.trailing, UIMetrics.servicePageSideInset)
    }
  }
}

extension ServicePageSectionHeader where Trailing == EmptyView {
  init(title: String, isExpanded: Binding<Bool>, theme: Theme, metrics: UIMetrics) {
    self.init(title: title, isExpanded: isExpanded, theme: theme, metrics: metrics, detail: nil) {
      EmptyView()
    }
  }
}
