import MultishellAppCore
import MultishellCore
import SwiftUI

/// Children sized by weight along one axis, with draggable dividers.
///
/// `HSplitView` and `VSplitView` decide sizes themselves and expose nothing,
/// which is how a second split ended up 90/5/5. This one takes the weights as
/// truth and reports the new ones when a divider moves.
struct WeightedSplit<Content: View>: View {
  let axis: SplitAxis
  let weights: [Double]
  let divider: Color
  let background: Color
  let onWeightsChange: ([Double]) -> Void
  @ViewBuilder let content: () -> Content

  // Constants live outside the generic type: static stored properties are
  // not allowed inside one.
  private var dividerThickness: CGFloat { SplitMetrics.dividerThickness }
  private var minimumPane: CGFloat { SplitMetrics.minimumPane }

  @State private var dragStartWeights: [Double]?

  var body: some View {
    GeometryReader { geometry in
      let length = axis == .horizontal ? geometry.size.width : geometry.size.height
      let available = max(length - CGFloat(weights.count - 1) * dividerThickness, 0)
      let total = weights.reduce(0, +)
      let sizes = weights.map {
        total > 0 ? available * CGFloat($0 / total) : available / CGFloat(weights.count)
      }

      layout(sizes: sizes, available: available, total: total)
    }
  }

  @ViewBuilder
  private func layout(sizes: [CGFloat], available: CGFloat, total: Double) -> some View {
    let stack = _VariadicView.Tree(
      SplitRoot(
        axis: axis, sizes: sizes, divider: divider, background: background,
        thickness: dividerThickness
      ) { index, translation in
        resize(dividerAfter: index, by: translation, available: available)
      } onDragEnded: {
        dragStartWeights = nil
      }
    ) {
      content()
    }
    stack
  }

  /// The drag is measured from where it began, so the weights it started
  /// from are remembered until it ends.
  private func resize(dividerAfter index: Int, by translation: CGFloat, available: CGFloat) {
    let start = dragStartWeights ?? weights
    if dragStartWeights == nil { dragStartWeights = start }
    let updated = SplitMath.transferring(
      Double(translation), acrossDividerAfter: index, in: start,
      available: Double(available), minimumPane: Double(minimumPane))
    if updated != start { onWeightsChange(updated) }
  }
}

private enum SplitMetrics {
  /// Layout space the divider occupies. Wider than the visible line because
  /// the panes are NSViews, which take mouse events before any SwiftUI
  /// overlay that spills onto them; the grab area has to be its own strip.
  static let dividerThickness: CGFloat = 6
  static let lineThickness: CGFloat = 1
  static let minimumPane: CGFloat = 80
}

/// Places the split's children with explicit sizes and a divider between
/// each pair. Variadic so `WeightedSplit` can take a `ForEach` as content.
private struct SplitRoot: _VariadicView_MultiViewRoot {
  let axis: SplitAxis
  let sizes: [CGFloat]
  let divider: Color
  let background: Color
  let thickness: CGFloat
  let onDrag: (Int, CGFloat) -> Void
  let onDragEnded: () -> Void

  @ViewBuilder
  func body(children: _VariadicView.Children) -> some View {
    let items = Array(children.enumerated())
    if axis == .horizontal {
      HStack(spacing: 0) { panes(items) }
    } else {
      VStack(spacing: 0) { panes(items) }
    }
  }

  @ViewBuilder
  private func panes(_ items: [(offset: Int, element: _VariadicView.Children.Element)]) -> some View
  {
    ForEach(items, id: \.element.id) { index, child in
      sized(child, index)
      if index < items.count - 1 {
        handle(after: index)
      }
    }
  }

  @ViewBuilder
  private func sized(_ child: _VariadicView.Children.Element, _ index: Int) -> some View {
    let size = sizes.indices.contains(index) ? sizes[index] : 0
    if axis == .horizontal {
      child.frame(width: size)
    } else {
      child.frame(height: size)
    }
  }

  private func handle(after index: Int) -> some View {
    background
      .frame(
        width: axis == .horizontal ? thickness : nil, height: axis == .vertical ? thickness : nil
      )
      .overlay {
        divider.frame(
          width: axis == .horizontal ? SplitMetrics.lineThickness : nil,
          height: axis == .vertical ? SplitMetrics.lineThickness : nil
        )
      }
      .contentShape(.rect)
      .onHover { inside in
        if inside {
          (axis == .horizontal ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
        } else {
          NSCursor.pop()
        }
      }
      .gesture(
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
          .onChanged { value in
            onDrag(index, axis == .horizontal ? value.translation.width : value.translation.height)
          }
          .onEnded { _ in onDragEnded() }
      )
  }
}
