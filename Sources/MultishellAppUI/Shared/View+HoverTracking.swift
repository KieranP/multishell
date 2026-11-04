import SwiftUI

extension View {
  func tracksHover(_ isHovered: Binding<Bool>) -> some View {
    modifier(HoverTrackingModifier(isHovered: isHovered))
  }
}
