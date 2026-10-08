import MultishellCore
import SwiftUI

/// A number in a debug table's fixed-width column, right-aligned so the
/// digits line up down the rows.
struct DebugNumberCell: View {
  let text: String
  let width: Double
  let color: Color

  var body: some View {
    Text(text)
      .monospacedDigit()
      .foregroundStyle(color)
      .frame(width: width, alignment: .trailing)
  }
}
