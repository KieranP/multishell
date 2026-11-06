import SwiftUI

/// A titled card of settings rows, ruled between rows, with an optional line
/// beneath it. A `SettingsCaption` row sits under the row it explains, unruled.
struct SettingsGroup<Content: View, Header: View, Footer: View>: View {
  @ViewBuilder let content: () -> Content
  @ViewBuilder let header: () -> Header
  @ViewBuilder let footer: () -> Footer

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if Header.self != EmptyView.self {
        header()
          .font(.system(size: UIMetrics.settingsSmallTextSize, weight: .semibold))
          .foregroundStyle(SettingsColors.secondaryText)
          .padding(.horizontal, UIMetrics.settingsGroupTitleInset)
          .padding(.bottom, 6)
      }
      card
      if Footer.self != EmptyView.self {
        footer()
          .padding(.horizontal, UIMetrics.settingsRowSideInset)
          .padding(.top, 6)
      }
    }
  }

  private var card: some View {
    VStack(alignment: .leading, spacing: 0) {
      Group(subviews: content()) { rows in
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
          // A caption tucks under the row before it; one opening the card is a row itself.
          let isCaption = index > 0 && row.containerValues.isSettingsRowCaption
          if index > 0, !isCaption {
            SettingsColors.rule
              .frame(height: UIMetrics.settingsRuleThickness)
              .padding(.horizontal, UIMetrics.settingsRowSideInset)
          }
          row
            .padding(.horizontal, UIMetrics.settingsRowSideInset)
            .padding(.top, isCaption ? 0 : 6)
            .padding(.bottom, isCaption ? 8 : 6)
            .frame(minHeight: isCaption ? 0 : UIMetrics.settingsRowMinHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .settingsCardFace(radius: UIMetrics.settingsCardRadius)
  }
}

extension SettingsGroup where Header == EmptyView, Footer == EmptyView {
  init(@ViewBuilder content: @escaping () -> Content) {
    self.init(content: content, header: { EmptyView() }, footer: { EmptyView() })
  }
}

extension SettingsGroup where Header == Text, Footer == EmptyView {
  init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
    self.init(content: content, header: { Text(title) }, footer: { EmptyView() })
  }
}

extension SettingsGroup where Footer == EmptyView {
  init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder header: @escaping () -> Header) {
    self.init(content: content, header: header, footer: { EmptyView() })
  }
}
