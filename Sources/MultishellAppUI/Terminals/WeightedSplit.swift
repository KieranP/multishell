import MultishellAppCore
import MultishellCore
import SwiftUI

/// Children sized by weight along one axis, with draggable dividers.
/// `HSplitView` decides sizes itself and exposes nothing; this does not.
struct WeightedSplit<Content: View>: View {
  let axis: SplitAxis
  let weights: [Double]
  let theme: Theme
  let onWeightsChange: ([Double]) -> Void
  @ViewBuilder let content: () -> Content

  @State private var drag = SplitDrag()

  var body: some View {
    let shownWeights = drag.shown(over: weights)
    GeometryReader { geometry in
      let length = axis == .horizontal ? geometry.size.width : geometry.size.height
      let available = SplitMath.available(
        Double(length),
        panes: shownWeights.count,
        divider: UIMetrics.splitDividerThickness,
      )
      let sizes = SplitMath.sizes(of: shownWeights, sharing: available).map { CGFloat($0) }

      layout(sizes: sizes, available: CGFloat(available))
    }
    .onChange(of: weights) { drag.forgetShownWeights() }
  }

  private func layout(sizes: [CGFloat], available: CGFloat) -> some View {
    Group(subviews: content()) { subviews in
      SplitStack(subviews: subviews, axis: axis, sizes: sizes, theme: theme) {
        index,
        translation in
        resize(dividerAfter: index, by: translation, available: available)
      } onDragEnded: {
        if let moved = drag.end(over: weights) { onWeightsChange(moved) }
      }
    }
  }

  private func resize(dividerAfter index: Int, by translation: CGFloat, available: CGFloat) {
    drag.move(
      dividerAfter: index,
      by: Double(translation),
      over: weights,
      available: Double(available),
      minimumPane: UIMetrics.minimumPaneLength,
    )
  }
}
