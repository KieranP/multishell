import MultishellCore
import SwiftUI

/// A session state's colour as a dot, the one mark a row, a lane and a
/// worker share.
struct StateDot: View {
  let state: SessionState
  let theme: Theme
  var diameter: Double = 7

  var body: some View {
    Circle()
      .fill(theme.color(for: state))
      .frame(width: diameter, height: diameter)
  }
}
