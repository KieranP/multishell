import MultishellCore
import SwiftUI

/// A toggle drawn as a knob on a track in its section's colours: the track the accent
/// while on and the fill while off, under the section's knob.
struct KnobToggleStyle: ToggleStyle {
  private static let trackSize = CGSize(width: 26, height: 15)

  let theme: Theme
  let section: InterfaceSection

  func makeBody(configuration: Configuration) -> some View {
    let isOn = configuration.isOn
    let knobDiameter = Self.trackSize.height - 4
    return Button {
      configuration.isOn.toggle()
    } label: {
      HStack(spacing: 6) {
        configuration.label
        Capsule()
          .fill(isOn ? theme.color(.accent, in: section) : AreaPalette(theme, section).fill)
          .frame(width: Self.trackSize.width, height: Self.trackSize.height)
          .overlay(alignment: isOn ? .trailing : .leading) {
            Circle()
              .fill(theme.color(.knob, in: section))
              .frame(width: knobDiameter, height: knobDiameter)
              .padding(2)
          }
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .selectableButtonTraits(isSelected: isOn)
  }
}
