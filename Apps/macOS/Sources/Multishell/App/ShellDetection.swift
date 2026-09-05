import Foundation
import MultishellCore
import MultishellProcess

/// Which shells this machine has, and how the dropdown lists them.
///
/// `/etc/shells` is the system's list, and Homebrew installs do not always
/// register there, so the login shell's PATH is searched for the usual
/// names as well. A stored path that is no longer installed is listed,
/// marked as such, rather than dropped: a picker whose selection is not in
/// its list shows blank.
struct ShellDetection: Equatable {
  struct Option: Identifiable, Equatable {
    let id: String
    let label: String
    let isInstalled: Bool
  }

  /// Paths of the shells found, sorted by name then path.
  let installed: [String]
  let loginShell: String

  static let empty = ShellDetection(installed: [], loginShell: ShellCatalogue.loginShellPath())

  init(installed: [String], loginShell: String) {
    self.installed = installed
    self.loginShell = loginShell
  }

  init(
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
  static func listed(in file: URL) -> [String] {
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

  static func name(_ path: String) -> String {
    URL(fileURLWithPath: path).lastPathComponent
  }

  func isInstalled(_ path: String) -> Bool {
    path == ShellCatalogue.loginShellID || installed.contains(path)
  }

  /// The login shell first, then every installed shell, then the selected
  /// one if it is not installed.
  func options(selected: String?) -> [Option] {
    var options = [
      Option(
        id: ShellCatalogue.loginShellID, label: "Login shell (\(loginShell))", isInstalled: true)
    ]
    for path in installed {
      options.append(Option(id: path, label: "\(Self.name(path))  \(path)", isInstalled: true))
    }
    if let selected, !isInstalled(selected) {
      options.append(
        Option(
          id: selected, label: "\(Self.name(selected))  \(selected) (not installed)",
          isInstalled: false))
    }
    return options
  }
}
