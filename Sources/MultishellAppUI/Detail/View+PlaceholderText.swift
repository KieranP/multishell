import MultishellCore
import SwiftUI

/// The title and caption under the icon of a detail area with no terminal.
extension View {
  func placeholderTitle(_ theme: Theme) -> some View {
    font(.system(size: 18, weight: .semibold))
      .foregroundStyle(theme.textPrimary)
      .padding(.top, 20)
  }

  func placeholderCaption(_ theme: Theme) -> some View {
    font(.system(size: 13))
      .foregroundStyle(theme.textSecondary)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 380)
      .padding(.top, 6)
  }
}
