import Foundation
import MultishellCore
import MultishellProcess

/// Which shells this machine has. `/etc/shells` is the system's list, and
/// the PATH is searched too, Homebrew not always registering there.
public struct ShellDetection: Equatable, Sendable {
  static let empty = Self(
    found: [],
    loginShell: ShellChoice.loginShellPath(),
  )

  /// Paths of the shells found, sorted by name then path.
  let found: [String]
  let loginShell: String
  /// Whether `$SHELL` points at something, read once here rather than per
  /// row: a stat on a dead mount blocks for its timeout.
  private let loginShellExists: Bool

  init(found: [String], loginShell: String) {
    self.found = found
    self.loginShell = loginShell
    self.loginShellExists = FileManager.default.isExecutableFile(atPath: loginShell)
  }

  init(
    searchPath: String?,
    systemList: URL = URL(fileURLWithPath: "/etc/shells"),
    loginShell: String = ShellChoice.loginShellPath(),
  ) {
    var found = Set(Self.listed(in: systemList))
    for name in ShellChoice.extraShellNamesToSearch {
      if let executable = ExecutableLookup.find(name, searchPath: searchPath) {
        found.insert(executable.path)
      }
    }
    self.init(found: Self.sorted(found), loginShell: loginShell)
  }

  /// Lines of `/etc/shells` that are executables, comments and blanks
  /// skipped.
  private static func listed(in file: URL) -> [String] {
    guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
    return LineList.entries(in: text).filter { FileManager.default.isExecutableFile(atPath: $0) }
  }

  private static func sorted(_ paths: Set<String>) -> [String] {
    paths.sorted { a, b in
      let (nameA, nameB) = (a.executableName, b.executableName)
      return nameA == nameB ? a < b : nameA < nameB
    }
  }

  /// `id` is a shell's path, or the login or custom entry's id.
  func isInstalled(_ id: String) -> Bool {
    id == ShellChoice.loginShellID
      ? loginShellExists : id == ShellChoice.customID || found.contains(id)
  }

  /// The login shell first, then every installed shell, then the selected
  /// one if it is not installed, then the custom path.
  public func options(selected: String?) -> [DetectionOption] {
    var options = [
      DetectionOption(
        id: ShellChoice.loginShellID,
        label: t("option.login-shell", loginShell),
      )
    ]
    for path in found {
      options.append(
        DetectionOption(id: path, label: t("option.shell-path", path.executableName, path))
      )
    }
    if let selected, !isInstalled(selected) {
      options.append(
        DetectionOption(
          id: selected,
          label: t("option.shell-not-installed", selected.executableName, selected),
        )
      )
    }
    options.append(DetectionOption(id: ShellChoice.customID, label: t("option.custom-path")))
    return options
  }
}
