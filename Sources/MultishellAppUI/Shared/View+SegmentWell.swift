import SwiftUI

extension View {
  /// The well a segment or a row of them sits in.
  func segmentWell(_ palette: AreaPalette) -> some View {
    padding(2)
      .background(palette.fill, in: RoundedRectangle(cornerRadius: 6))
      .fixedSize()
  }
}
