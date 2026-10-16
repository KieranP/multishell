import MultishellCore
import SwiftUI

extension View {
  func tabFace(
    isShown: Bool,
    theme: Theme,
    activate: @escaping () -> Void,
    close: @escaping () -> Void,
  ) -> some View {
    modifier(TabFaceModifier(isShown: isShown, theme: theme, activate: activate, close: close))
  }
}
