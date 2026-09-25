import Foundation
import MultishellCore

extension ShellCatalogue {
  /// A path is its own name; the login shell and the custom path say what
  /// they currently resolve to.
  static func displayName(_ id: String?, customPath: String, loginShell: String) -> String {
    guard let id, id != loginShellID else { return t("shell.named-login-shell", loginShell) }
    guard id == customID else { return id }
    let path = customPath.trimmingCharacters(in: .whitespaces)
    return path.isEmpty
      ? t("shell.named-custom-blank") : t("shell.named-custom-path", path)
  }
}
