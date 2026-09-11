import MultishellCore
import SwiftUI

/// A one-symbol button for the settings windows, a word beside a dropdown
/// pushing rows onto two lines. One symbol and help per meaning.
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
  static func refresh(
    help: String = t("action.refresh"), action: @escaping () -> Void
  )
    -> IconButton
  {
    IconButton(symbol: "arrow.clockwise", help: help, action: action)
  }

  /// Shows a file or folder in the Finder.
  static func reveal(
    help: String = t("action.reveal-in-finder"), action: @escaping () -> Void
  )
    -> IconButton
  {
    IconButton(symbol: "magnifyingglass", help: help, action: action)
  }
}
