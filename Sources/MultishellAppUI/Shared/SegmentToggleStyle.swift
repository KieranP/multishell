import MultishellCore
import SwiftUI

/// A toggle drawn as one segment in its well, on its pill while on: the
/// system's button-style toggle draws in its own colours.
struct SegmentToggleStyle: ToggleStyle {
  let palette: AreaPalette
  let metrics: UIMetrics

  func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      SegmentFace(
        isSelected: configuration.isOn,
        palette: palette,
        metrics: metrics,
        content: { configuration.label },
      )
    }
    .buttonStyle(.plain)
    .segmentWell(palette)
    .selectableButtonTraits(isSelected: configuration.isOn)
  }
}
