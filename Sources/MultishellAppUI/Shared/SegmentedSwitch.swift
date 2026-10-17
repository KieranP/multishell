import MultishellCore
import SwiftUI

/// A few choices side by side in one section's colours, the selected one on a
/// pill: the system's segmented control draws in its own, whatever the theme says.
struct SegmentedSwitch<Value: Hashable>: View {
  /// What a screen reader calls the whole switch.
  let label: String
  let options: [(title: String, value: Value)]
  @Binding var selection: Value
  let theme: Theme
  let section: InterfaceSection
  let metrics: UIMetrics

  var body: some View {
    HStack(spacing: 2) {
      ForEach(options.indices, id: \.self) { index in
        let option = options[index]
        let isSelected = option.value == selection
        Button {
          selection = option.value
        } label: {
          SegmentFace(isSelected: isSelected, theme: theme, section: section, metrics: metrics) {
            Text(option.title)
          }
        }
        .buttonStyle(.plain)
        .selectableButtonTraits(isSelected: isSelected)
      }
    }
    .segmentWell(AreaPalette(theme, section))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(label)
  }
}
