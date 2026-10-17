import SwiftUI

extension View {
  /// A small segmented picker as wide as its labels, for a bar or a header.
  func compactSegmented() -> some View {
    pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
      .controlSize(.small)
  }
}
