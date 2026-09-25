import SwiftUI

extension View {
  /// The start of a drag that stays in the app, with the two ways it ends
  /// when no drop takes it.
  func inAppDragSource(
    begin: @escaping () -> NSItemProvider,
    ended: @escaping () -> Void,
    sourceLeft: @escaping (_ isPressed: @escaping @MainActor () -> Bool) -> Void
  ) -> some View {
    onDrag(begin).modifier(InAppDragEnds(ended: ended, sourceLeft: sourceLeft))
  }

  func inAppDragSource<Preview: View>(
    begin: @escaping () -> NSItemProvider,
    @ViewBuilder preview: () -> Preview,
    ended: @escaping () -> Void,
    sourceLeft: @escaping (_ isPressed: @escaping @MainActor () -> Bool) -> Void
  ) -> some View {
    onDrag(begin, preview: preview)
      .modifier(InAppDragEnds(ended: ended, sourceLeft: sourceLeft))
  }
}

private struct InAppDragEnds: ViewModifier {
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
