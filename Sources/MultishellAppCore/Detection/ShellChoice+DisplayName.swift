import Foundation
import MultishellCore

extension ShellChoice {
  /// A path is its own name; the login shell and the custom path say what
  /// they currently resolve to.
  static func displayName(_ id: String?, customPath: String, loginShell: String) -> String {
    guard let id, id != loginShellID else { return t("shell.named-login-shell", loginShell) }
    guard id == customID else { return id }
    guard let path = runnablePath(customPath) else { return t("shell.named-custom-blank") }
    return t("shell.named-custom-path", path)
  }
}
