import Foundation

extension Bundle {
  /// Where the libraries' resources are at runtime: the catalogue, the
  /// shell-integration scripts and the built-in themes, which ship in one bundle.
  static let coreResources = PackageBundle.holding(
    "Localizable",
    withExtension: "strings",
    named: "multishell_MultishellCore.bundle",
    or: .module,
  )
}
