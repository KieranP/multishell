import SwiftUI

extension View {
  /// A segmented picker spanning its row, which the macOS 26 style draws only
  /// as wide as its labels otherwise; see Docs/design/appearance.md.
  func segmentedAcrossRow() -> some View {
    pickerStyle(.segmented)
      .buttonSizing(.flexible)
      .labelsHidden()
  }
}
