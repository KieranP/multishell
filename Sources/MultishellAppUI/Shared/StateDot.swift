import MultishellCore
import SwiftUI

/// A session state's colour as a dot, the one mark a row, a lane and a
/// worker share.
struct StateDot: View {
  let state: SessionState
  let theme: Theme
  /// What the dot sits on, for idle's grey.
  let palette: AreaPalette
  var diameter: Double = 7

  var body: some View {
    Circle()
      .fill(theme.color(for: state, on: palette))
      .frame(width: diameter, height: diameter)
  }
}
