import MultishellCore
import SwiftUI

/// The large faint symbol over a detail placeholder with nothing under way.
struct PlaceholderSymbol: View {
  let symbol: String
  let theme: Theme

  var body: some View {
    Image(systemName: symbol)
      .font(.system(size: 40, weight: .light))
      .foregroundStyle(theme.detail.textTertiary)
      .accessibilityHidden(true)
  }
}
