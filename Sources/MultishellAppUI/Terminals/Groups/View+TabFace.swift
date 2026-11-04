import MultishellCore
import SwiftUI

extension View {
  func tabFace(
    isShown: Bool,
    wash: Color?,
    shownFill: Color,
    theme: Theme,
    activate: @escaping () -> Void,
    close: @escaping () -> Void,
  ) -> some View {
    modifier(
      TabFaceModifier(
        isShown: isShown,
        wash: wash,
        shownFill: shownFill,
        theme: theme,
        activate: activate,
        close: close,
      )
    )
  }
}
