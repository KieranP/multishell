import MultishellAppCore
import MultishellCore
import SwiftUI

/// Children sized by weight along one axis, with draggable dividers.
/// `HSplitView` decides sizes itself and exposes nothing; this does not.
struct WeightedSplit<Content: View>: View {
  let axis: SplitAxis
  let weights: [Double]
  let dividerColor: Color
  let gutterColor: Color
  let onWeightsChange: ([Double]) -> Void
  @ViewBuilder let content: () -> Content

  @State private var dragStartWeights: [Double]?
  /// The weights as the drag has them, handed to the model once at its end:
  /// each frame written through re-rendered every reader and re-armed autosave.
  @State private var liveWeights: [Double]?

  var body: some View {
    let shownWeights = liveWeights ?? weights
    GeometryReader { geometry in
      let length = axis == .horizontal ? geometry.size.width : geometry.size.height
      let available = SplitMath.available(
        Double(length), panes: shownWeights.count, divider: UIMetrics.splitDividerThickness)
      let sizes = SplitMath.sizes(of: shownWeights, sharing: available).map { CGFloat($0) }

      layout(sizes: sizes, available: CGFloat(available))
    }
    .onChange(of: weights) { liveWeights = nil }
  }

  private func layout(sizes: [CGFloat], available: CGFloat) -> some View {
    Group(subviews: content()) { subviews in
      SplitStack(
        subviews: subviews, axis: axis, sizes: sizes, dividerColor: dividerColor,
        gutterColor: gutterColor,
        thickness: CGFloat(UIMetrics.splitDividerThickness)
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
      available: Double(available), minimumPane: UIMetrics.minimumPaneLength)
    if updated != (liveWeights ?? start) { liveWeights = updated }
  }
}
