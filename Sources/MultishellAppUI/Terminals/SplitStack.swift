import MultishellCore
import SwiftUI

/// Places the split's children with explicit sizes and a divider between
/// each pair. Built from subviews so `WeightedSplit` can take a `ForEach`.
struct SplitStack: View {
  let subviews: SubviewsCollection
  let axis: SplitAxis
  let sizes: [CGFloat]
  let theme: Theme
  let onDrag: (Int, CGFloat) -> Void
  let onDragEnded: () -> Void

  var body: some View {
    if axis == .horizontal {
      HStack(spacing: 0) { panes }
    } else {
      VStack(spacing: 0) { panes }
    }
  }

  private var panes: some View {
    ForEach(Array(subviews.enumerated()), id: \.element.id) { index, child in
      sized(child, index)
      if index < subviews.count - 1 {
        divider(after: index)
      }
    }
  }

  @ViewBuilder
  private func sized(_ child: Subview, _ index: Int) -> some View {
    let size = sizes.indices.contains(index) ? sizes[index] : 0
    if axis == .horizontal {
      child.frame(width: size)
    } else {
      child.frame(height: size)
    }
  }

  private func divider(after index: Int) -> some View {
    SplitDivider(
      axis: axis, theme: theme, onDrag: { onDrag(index, $0) }, onDragEnded: onDragEnded)
  }
}
