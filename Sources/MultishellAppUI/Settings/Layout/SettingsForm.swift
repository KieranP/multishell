import SwiftUI

/// A settings page: its groups down a scrolling column on the page colour,
/// each row laid out label left, control right.
struct SettingsForm<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: UIMetrics.settingsGroupSpacing) {
        content()
      }
      .padding(.top, UIMetrics.settingsPageTopInset)
      .padding(.horizontal, UIMetrics.settingsPageSideInset)
      .padding(.bottom, UIMetrics.settingsPageBottomInset)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollEdgeEffectHidden(true, for: .top)
    .background(SettingsColors.page)
    .labeledContentStyle(SettingsRowStyle())
    .textFieldStyle(.roundedBorder)
    .buttonStyle(SettingsButtonStyle())
  }
}
