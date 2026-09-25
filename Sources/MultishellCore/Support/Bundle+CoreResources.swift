import Foundation

extension Bundle {
  /// Where the libraries' resources are at runtime: the catalogue and the
  /// shell-integration scripts, which ship in one bundle.
  static let coreResources = PackageBundle.holding(
    "Localizable", withExtension: "strings", named: "multishell_MultishellCore.bundle",
    or: .module)
}
