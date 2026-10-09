import MultishellCore
import SwiftUI

/// One divider. The end of a drag is read off the gesture state resetting,
/// which a cancelled gesture does too where `onEnded` would stay silent.
struct SplitDivider: View {
  let axis: SplitAxis
  let theme: Theme
  let onDrag: (CGFloat) -> Void
  let onDragEnded: () -> Void

  @GestureState private var isDragging = false

  var body: some View {
    let thickness = CGFloat(UIMetrics.splitDividerThickness)
    return theme.chromeColor
      .frame(
        width: axis == .horizontal ? thickness : nil,
        height: axis == .vertical ? thickness : nil,
      )
      .overlay {
        theme.hairline.frame(
          width: axis == .horizontal ? CGFloat(UIMetrics.splitLineThickness) : nil,
          height: axis == .vertical ? CGFloat(UIMetrics.splitLineThickness) : nil,
        )
      }
      .contentShape(.rect)
      .pointerStyle(
        axis == .horizontal ? .columnResize(directions: .all) : .rowResize(directions: .all)
      )
      .gesture(
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
          .updating($isDragging) { _, dragging, _ in dragging = true }
          .onChanged { value in
            onDrag(axis == .horizontal ? value.translation.width : value.translation.height)
          }
      )
      .onChange(of: isDragging) { _, dragging in
        if !dragging { onDragEnded() }
      }
  }
}
