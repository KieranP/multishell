import SwiftUI

extension View {
  /// Never narrower than `sample` in `font`, and as wide as the row leaves,
  /// so the badges beside a name give way before the name does.
  func reservingWidth(of sample: String, in font: Font) -> some View {
    ZStack(alignment: .leading) {
      Text(verbatim: sample).font(font).fixedSize().hidden()
      self
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
