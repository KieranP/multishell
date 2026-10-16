import MultishellCore
import SwiftUI

extension View {
  func filterWell(theme: Theme, metrics: UIMetrics) -> some View {
    modifier(FilterWellModifier(theme: theme, metrics: metrics))
  }
}
