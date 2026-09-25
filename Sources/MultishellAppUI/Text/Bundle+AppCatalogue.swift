import Foundation
import MultishellCore

extension Bundle {
  /// Where this app's catalogue is at runtime.
  static let appCatalogue = PackageBundle.holding(
    "Localizable", withExtension: "strings", named: "multishell_MultishellAppUI.bundle", or: .module
  )
}
