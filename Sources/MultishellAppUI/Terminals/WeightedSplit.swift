import MultishellAppCore
import MultishellCore
import SwiftUI

/// Children sized by weight along one axis, with draggable dividers.
/// `HSplitView` decides sizes itself and exposes nothing; this does not.
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
  /// The weights as the drag has them, handed to the model once at its end:
  /// each frame written through re-rendered every reader and re-armed autosave.
  @State private var liveWeights: [Double]?

  var body: some View {
    let weights = liveWeights ?? weights
    GeometryReader { geometry in
      let length = axis == .horizontal ? geometry.size.width : geometry.size.height
      let available = SplitMath.available(
        Double(length), panes: weights.count, divider: Double(dividerThickness))
      let sizes = SplitMath.sizes(of: weights, sharing: available).map { CGFloat($0) }

      layout(sizes: sizes, available: CGFloat(available))
    }
    .onChange(of: self.weights) { liveWeights = nil }
  }

  private func layout(sizes: [CGFloat], available: CGFloat) -> some View {
    Group(subviews: content()) { subviews in
      SplitPanes(
        subviews: subviews, axis: axis, sizes: sizes, divider: divider, background: background,
        thickness: dividerThickness
      ) { index, translation in
        resize(dividerAfter: index, by: translation, available: available)
      } onDragEnded: {
        if let live = liveWeights, live != weights { onWeightsChange(live) }
        dragStartWeights = nil
        liveWeights = nil
      }
    }
  }

  /// The drag is measured from where it began, so the weights it started
  /// from are remembered until it ends.
  private func resize(dividerAfter index: Int, by translation: CGFloat, available: CGFloat) {
    let start = dragStartWeights ?? weights
    if dragStartWeights == nil { dragStartWeights = start }
    let updated = SplitMath.transferring(
      Double(translation), acrossDividerAfter: index, in: start,
      available: Double(available), minimumPane: Double(minimumPane))
    if updated != (liveWeights ?? start) { liveWeights = updated }
  }
}

/// Places the split's children with explicit sizes and a divider between
/// each pair. Built from subviews so `WeightedSplit` can take a `ForEach`.
private struct SplitPanes: View {
  let subviews: SubviewsCollection
  let axis: SplitAxis
  let sizes: [CGFloat]
  let divider: Color
  let background: Color
  let thickness: CGFloat
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
        handle(after: index)
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

  private func handle(after index: Int) -> some View {
    SplitHandle(
      axis: axis, thickness: thickness, divider: divider, background: background,
      onDrag: { onDrag(index, $0) }, onDragEnded: onDragEnded)
  }
}

/// One divider. The end of a drag is read off the gesture state resetting,
/// which a cancelled gesture does too where `onEnded` would stay silent.
private struct SplitHandle: View {
  let axis: SplitAxis
  let thickness: CGFloat
  let divider: Color
  let background: Color
  let onDrag: (CGFloat) -> Void
  let onDragEnded: () -> Void

  @GestureState private var isDragging = false

  var body: some View {
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
