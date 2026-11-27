import MultishellCore
import SwiftUI

extension View {
  func reviewCardFrame(theme: Theme, isSelected: Bool = false) -> some View {
    modifier(ReviewCardFrameModifier(theme: theme, isSelected: isSelected))
  }
}
