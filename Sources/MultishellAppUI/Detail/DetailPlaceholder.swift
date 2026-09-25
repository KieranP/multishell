import MultishellCore
import SwiftUI

/// A detail area with no terminal in it: an icon, a title and a caption,
/// then whatever the caller puts under them.
struct DetailPlaceholder<Icon: View, Extra: View>: View {
  let title: String
  let caption: String
  let theme: Theme
  @ViewBuilder let icon: () -> Icon
  @ViewBuilder let extra: () -> Extra

  var body: some View {
    VStack(spacing: 0) {
      icon()
      Text(title)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(theme.textPrimary)
        .padding(.top, 20)
      Text(caption)
        .font(.system(size: 13))
        .foregroundStyle(theme.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 380)
        .padding(.top, 6)
      extra()
    }
    .padding(48)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
