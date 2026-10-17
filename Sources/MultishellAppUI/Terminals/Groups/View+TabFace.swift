import MultishellCore
import SwiftUI

extension View {
  func tabFace(
    isShown: Bool,
    shownFill: Color,
    theme: Theme,
    activate: @escaping () -> Void,
    close: @escaping () -> Void,
  ) -> some View {
    modifier(
      TabFaceModifier(
        isShown: isShown,
        shownFill: shownFill,
        theme: theme,
        activate: activate,
        close: close,
      )
    )
  }
}
