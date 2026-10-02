import SwiftUI

struct InAppDragSourceModifier: ViewModifier {
  let onEnded: () -> Void
  let onSourceLeft: (_ isPressed: @escaping @MainActor () -> Bool) -> Void

  @Environment(\.primaryMouseButton) private var primaryMouseButton

  func body(content: Content) -> some View {
    content
      .dragConfiguration(.insideTheAppOnly)
      // After any drop has run, so this ends only a drag nothing took.
      .onDragSessionUpdated { session in
        if case .ended = session.phase { onEnded() }
      }
      // The session's end reaches only a source still on screen.
      .onDisappear {
        onSourceLeft({ [primaryMouseButton] in primaryMouseButton.isPressed })
      }
  }
}
