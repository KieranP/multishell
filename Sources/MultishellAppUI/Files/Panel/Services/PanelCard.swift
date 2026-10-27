import MultishellCore
import SwiftUI

/// The box at the top of a services' page holding what the page is about,
/// on the header's fill so it reads apart from the list under it.
struct PanelCard<Content: View>: View {
  let theme: Theme
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 6, content: content)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        theme.header.background,
        in: RoundedRectangle(cornerRadius: UIMetrics.columnCornerRadius),
      )
      .overlay {
        RoundedRectangle(cornerRadius: UIMetrics.columnCornerRadius)
          .strokeBorder(theme.filesPanel.border, lineWidth: UIMetrics.hairlineThickness)
      }
      .padding(UIMetrics.servicePageSideInset)
  }
}
