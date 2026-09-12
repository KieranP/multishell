import Foundation
import MultishellCore
import MultishellProcess

/// Which shells this machine has. `/etc/shells` is the system's list, and
/// the PATH is searched too, Homebrew not always registering there.
public struct ShellDetection: Equatable, Sendable {
  /// Paths of the shells found, sorted by name then path.
  public let installed: [String]
  public let loginShell: String
  /// Whether `$SHELL` points at something. Every other row is checked, and a
  /// tab on a shell that is not there dies the moment it opens. Read once
  /// here, not per row: a stat on a dead mount blocks for its timeout.
  public let loginShellExists: Bool

  public static let empty = ShellDetection(
    installed: [], loginShell: ShellCatalogue.loginShellPath())

  public init(installed: [String], loginShell: String) {
    self.installed = installed
    self.loginShell = loginShell
    self.loginShellExists = FileManager.default.isExecutableFile(atPath: loginShell)
  }

  public init(
    path: String?,
    systemList: URL = URL(fileURLWithPath: "/etc/shells"),
    loginShell: String = ShellCatalogue.loginShellPath()
  ) {
    var found = Set(Self.listed(in: systemList))
    for name in ShellCatalogue.searched {
      if let executable = ExecutableLookup.find(name, path: path) { found.insert(executable.path) }
    }
    self.init(installed: Self.sorted(found), loginShell: loginShell)
  }

  /// Lines of `/etc/shells` that are executables, comments and blanks
  /// skipped.
  public static func listed(in file: URL) -> [String] {
    guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
    return text.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty && !$0.hasPrefix("#") }
      .filter { FileManager.default.isExecutableFile(atPath: $0) }
  }

  private static func sorted(_ paths: Set<String>) -> [String] {
    paths.sorted { a, b in
      let (na, nb) = (Self.name(a), Self.name(b))
      return na == nb ? a < b : na < nb
    }
  }

  public static func name(_ path: String) -> String {
    URL(fileURLWithPath: path).lastPathComponent
  }

  public func isInstalled(_ path: String) -> Bool {
    path == ShellCatalogue.loginShellID
      ? loginShellExists : path == ShellCatalogue.customID || installed.contains(path)
  }

  /// The login shell first, then every installed shell, then the selected
  /// one if it is not installed, then the custom path.
  public func options(selected: String?) -> [DetectionOption] {
    var options = [
      DetectionOption(
        id: ShellCatalogue.loginShellID, label: t("option.login-shell", loginShell),
        isInstalled: loginShellExists)
    ]
    for path in installed {
      options.append(
        DetectionOption(
          id: path, label: t("option.shell-path", Self.name(path), path), isInstalled: true))
    }
    if let selected, !isInstalled(selected) {
      options.append(
        DetectionOption(
          id: selected,
          label: t("option.shell-not-installed", Self.name(selected), selected),
          isInstalled: false))
    }
    options.append(
      DetectionOption(
        id: ShellCatalogue.customID, label: t("option.custom-path"), isInstalled: true))
    return options
  }
}
