import SwiftUI

extension View {
  /// A middle click, which SwiftUI has no gesture for.
  func onMiddleClick(perform action: @escaping () -> Void) -> some View {
    overlay { MiddleClickCatcher(onMiddleClick: action) }
  }
}
