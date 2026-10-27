import MultishellAppCore
import SwiftUI

/// The quick switcher when it is up, as the window's overlay. Its own view, so
/// each key typed redraws this and not the window reading it.
struct QuickSwitcherLayer: View {
  let model: AppModel

  var body: some View {
    if let state = model.quickSwitcher { QuickSwitcherOverlay(model: model, state: state) }
  }
}
