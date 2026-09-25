import MultishellCore
import SwiftUI

extension RGB {
  var color: Color {
    Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
  }
}
