import SwiftUI

extension View {
  /// The start of a drag that stays in the app, with the two ways it ends
  /// when no drop takes it.
  func inAppDragSource(
    begin: @escaping () -> NSItemProvider,
    ended: @escaping () -> Void,
    sourceLeft: @escaping (_ isPressed: @escaping @MainActor () -> Bool) -> Void
  ) -> some View {
    onDrag(begin).modifier(InAppDragEndModifier(ended: ended, sourceLeft: sourceLeft))
  }

  func inAppDragSource<Preview: View>(
    begin: @escaping () -> NSItemProvider,
    @ViewBuilder preview: () -> Preview,
    ended: @escaping () -> Void,
    sourceLeft: @escaping (_ isPressed: @escaping @MainActor () -> Bool) -> Void
  ) -> some View {
    onDrag(begin, preview: preview)
      .modifier(InAppDragEndModifier(ended: ended, sourceLeft: sourceLeft))
  }
}
