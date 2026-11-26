import SwiftUI

/// The Actions page's three columns, at one width for its heading and every
/// row: the name, the command taking what is left, and the keys.
struct ActionColumns<Name: View, Command: View, Keys: View>: View {
  @ViewBuilder let name: () -> Name
  @ViewBuilder let command: () -> Command
  @ViewBuilder let keys: () -> Keys

  var body: some View {
    HStack(spacing: UIMetrics.settingsColumnSpacing) {
      name()
        .frame(width: UIMetrics.settingsActionNameColumnWidth, alignment: .leading)
      command()
        .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 6) { keys() }
        .frame(width: UIMetrics.settingsActionKeysColumnWidth, alignment: .leading)
    }
  }
}
