import Foundation
import MultishellCore

extension Bundle {
  static let appCatalogue = PackageBundle.holding(
    "Localizable", withExtension: "strings", named: "multishell_MultishellAppUI.bundle", or: .module
  )
}
