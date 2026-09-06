import SwiftUI

/// A one-symbol button for the settings windows, where a word beside a
/// dropdown or a path pushed rows onto two lines. The symbol and the help
/// text are decided in one place per meaning, so every refresh and every
/// reveal reads the same.
struct IconButton: View {
  let symbol: String
  let help: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
    }
    .help(help)
    .accessibilityLabel(help)
  }

  /// Runs detection or a git read again.
  static func refresh(help: String = "Refresh", action: @escaping () -> Void) -> IconButton {
    IconButton(symbol: "arrow.clockwise", help: help, action: action)
  }

  /// Shows a file or folder in the Finder.
  static func reveal(help: String = "Reveal in Finder", action: @escaping () -> Void) -> IconButton
  {
    IconButton(symbol: "magnifyingglass", help: help, action: action)
  }
}
