import SwiftUI

struct InAppDragEnds: ViewModifier {
  let ended: () -> Void
  let sourceLeft: (_ isPressed: @escaping @MainActor () -> Bool) -> Void

  @Environment(\.primaryMouseButton) private var primaryMouseButton

  func body(content: Content) -> some View {
    content
      .dragConfiguration(.insideTheAppOnly)
      // After any drop has run, so this ends only a drag nothing took.
      .onDragSessionUpdated { session in
        if case .ended = session.phase { ended() }
      }
      // The session's end reaches only a source still on screen.
      .onDisappear {
        sourceLeft({ [primaryMouseButton] in primaryMouseButton.isDown })
      }
  }
}
