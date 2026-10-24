import SwiftUI

extension View {
  /// The well a segment or a row of them sits in, as wide as they are unless
  /// it `fillsWidth`.
  func segmentWell(_ palette: AreaPalette, fillsWidth: Bool = false) -> some View {
    padding(2)
      .background(palette.fill, in: RoundedRectangle(cornerRadius: 6))
      .fixedSize(horizontal: !fillsWidth, vertical: true)
  }
}
