import AppKit
import MultishellAppCore
import SwiftUI

/// AppKit's own checkbox: SwiftUI's draws no mixed state from a single value,
/// which a step's checkbox over some of its items needs.
struct HandoffCheckbox: NSViewRepresentable {
  @MainActor final class Coordinator: NSObject {
    var toggle: () -> Void
    var state: NSControl.StateValue = .off

    init(toggle: @escaping () -> Void) {
      self.toggle = toggle
    }

    /// The model decides the state, so AppKit's own cycling on the click is
    /// undone: a toggle that changes nothing would otherwise leave it showing.
    @objc func click(_ sender: NSButton) {
      sender.state = state
      toggle()
    }
  }

  let state: HandoffGroupState
  let label: String
  let toggle: () -> Void

  func makeNSView(context: Context) -> NSButton {
    let button = NSButton(
      checkboxWithTitle: "",
      target: context.coordinator,
      action: #selector(Coordinator.click(_:)),
    )
    button.allowsMixedState = true
    button.controlSize = .small
    button.setContentHuggingPriority(.required, for: .horizontal)
    return button
  }

  func updateNSView(_ button: NSButton, context: Context) {
    context.coordinator.toggle = toggle
    context.coordinator.state =
      switch state {
      case .checked: .on
      case .unchecked: .off
      case .mixed: .mixed
      }
    button.state = context.coordinator.state
    button.setAccessibilityLabel(label)
  }

  func makeCoordinator() -> Coordinator { Coordinator(toggle: toggle) }
}
