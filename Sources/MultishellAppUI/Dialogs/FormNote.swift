import SwiftUI

/// A line in the form standing in for something there is nothing to pick or
/// fill in for, or saying why Create is off.
struct FormNote<Tint: ShapeStyle>: View {
  let text: String
  let symbol: String
  let tint: Tint
  var dimsText = false

  var body: some View {
    Label {
      let line = Text(text).font(.system(size: 12))
      if dimsText { line.foregroundStyle(.secondary) } else { line }
    } icon: {
      Image(systemName: symbol).foregroundStyle(tint)
    }
  }
}
