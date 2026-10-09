import SwiftUI

extension View {
  /// The start of a drag that stays in the app, with the two ways it ends
  /// when no drop takes it.
  func inAppDragSource(
    begin: @escaping () -> NSItemProvider,
    onEnded: @escaping () -> Void,
    onSourceLeft: @escaping (_ isPressed: @escaping @MainActor () -> Bool) -> Void,
  ) -> some View {
    onDrag(begin).modifier(InAppDragSourceModifier(onEnded: onEnded, onSourceLeft: onSourceLeft))
  }

  func inAppDragSource<Preview: View>(
    begin: @escaping () -> NSItemProvider,
    @ViewBuilder preview: () -> Preview,
    onEnded: @escaping () -> Void,
    onSourceLeft: @escaping (_ isPressed: @escaping @MainActor () -> Bool) -> Void,
  ) -> some View {
    onDrag(begin, preview: preview)
      .modifier(InAppDragSourceModifier(onEnded: onEnded, onSourceLeft: onSourceLeft))
  }
}
