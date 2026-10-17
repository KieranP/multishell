import MultishellCore
import SwiftUI

/// A toggle drawn as one segment in its well, on its pill while on: the
/// system's button-style toggle draws in its own colours.
struct SegmentToggleStyle: ToggleStyle {
  let theme: Theme
  let section: InterfaceSection
  let metrics: UIMetrics

  func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      SegmentFace(
        isSelected: configuration.isOn,
        theme: theme,
        section: section,
        metrics: metrics,
        content: { configuration.label },
      )
    }
    .buttonStyle(.plain)
    .segmentWell(AreaPalette(theme, section))
    .selectableButtonTraits(isSelected: configuration.isOn)
  }
}
